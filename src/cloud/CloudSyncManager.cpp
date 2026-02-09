#include "CloudSyncManager.h"
#include "../database/DatabaseManager.h"

#include <QNetworkRequest>
#include <QHttpMultiPart>
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QStandardPaths>
#include <QDir>
#include <QSettings>
#include <QUuid>
#include <QDateTime>
#include <QVariant>

// Appwrite configuration
static const QString APPWRITE_ENDPOINT = "https://nyc.cloud.appwrite.io/v1";
static const QString APPWRITE_PROJECT_ID = "690f708900139eaa58f4";
static const QString DEFAULT_BUCKET_ID = "projects";

CloudSyncManager::CloudSyncManager(DatabaseManager *dbManager, QObject *parent)
    : QObject(parent)
    , m_dbManager(dbManager)
    , m_networkManager(new QNetworkAccessManager(this))
    , m_endpoint(APPWRITE_ENDPOINT)
    , m_projectId(APPWRITE_PROJECT_ID)
    , m_bucketId(DEFAULT_BUCKET_ID)
    , m_isUploading(false)
    , m_isDownloading(false)
    , m_uploadProgress(0.0)
    , m_downloadProgress(0.0)
    , m_chunkRetryCount(0)
{
    // Load saved settings
    QSettings settings;
    m_apiKey = settings.value("cloud/apiKey").toString();
    m_bucketId = settings.value("cloud/bucketId", DEFAULT_BUCKET_ID).toString();
    m_lastSyncTime = settings.value("cloud/lastSyncTime").toString();
}

CloudSyncManager::~CloudSyncManager()
{
}

void CloudSyncManager::setApiKey(const QString &apiKey)
{
    m_apiKey = apiKey;
    QSettings settings;
    settings.setValue("cloud/apiKey", apiKey);
    emit configuredChanged();
}

void CloudSyncManager::setBucketId(const QString &bucketId)
{
    if (m_bucketId != bucketId) {
        m_bucketId = bucketId;
        QSettings settings;
        settings.setValue("cloud/bucketId", bucketId);
        emit bucketIdChanged();
        emit configuredChanged();
    }
}

bool CloudSyncManager::isConfigured() const
{
    return !m_apiKey.isEmpty() && !m_bucketId.isEmpty();
}

QNetworkRequest CloudSyncManager::createRequest(const QString &path) const
{
    QUrl url(m_endpoint + path);
    QNetworkRequest request(url);

    request.setRawHeader("X-Appwrite-Project", m_projectId.toUtf8());
    if (!m_apiKey.isEmpty()) {
        request.setRawHeader("X-Appwrite-Key", m_apiKey.toUtf8());
    }
    request.setRawHeader("Content-Type", "application/json");

    return request;
}

QString CloudSyncManager::generateBackupFileName() const
{
    QString timestamp = QDateTime::currentDateTime().toString("yyyyMMdd_HHmmss");
    QString machineName = QSysInfo::machineHostName();
    return QString("sitesurveyor_%1_%2.db").arg(timestamp).arg(machineName);
}

void CloudSyncManager::setError(const QString &error)
{
    m_errorMessage = error;
    emit errorChanged();
    emit syncError(error);
    qWarning() << "CloudSync error:" << error;
}

void CloudSyncManager::clearError()
{
    if (!m_errorMessage.isEmpty()) {
        m_errorMessage.clear();
        emit errorChanged();
    }
}

// ============ UPLOAD DATABASE ============

void CloudSyncManager::uploadDatabase()
{
    if (m_isUploading) {
        setError(tr("Upload already in progress"));
        return;
    }

    if (!isConfigured()) {
        setError(tr("Cloud sync not configured. Please set API key."));
        return;
    }

    if (!m_dbManager || m_dbManager->databasePath().isEmpty()) {
        setError(tr("No database to upload"));
        return;
    }

    clearError();
    m_isUploading = true;
    m_uploadProgress = 0.0;
    emit uploadingChanged();
    emit syncingChanged();
    emit uploadProgressChanged();

    // Start chunked upload
    QString backupFileName = generateBackupFileName();
    QString backupPath = QStandardPaths::writableLocation(QStandardPaths::TempLocation) + "/" + backupFileName;

    // Copy the database file directly for upload
    QString dbPath = m_dbManager->databasePath();
    if (dbPath.isEmpty()) {
        setError(tr("No database path available"));
        m_isUploading = false;
        emit uploadingChanged();
        emit syncingChanged();
        return;
    }
    
    // Remove any existing temp file first
    QFile::remove(backupPath);
    
    if (!QFile::copy(dbPath, backupPath)) {
        setError(tr("Failed to create database copy for upload"));
        m_isUploading = false;
        emit uploadingChanged();
        emit syncingChanged();
        return;
    }
    
    QFile file(backupPath);
    if (!file.open(QIODevice::ReadOnly)) {
        setError(tr("Failed to open backup file for upload"));
        m_isUploading = false;
        emit uploadingChanged();
        emit syncingChanged();
        return;
    }

    m_chunkUploadBuffer = file.readAll();
    file.close();
    QFile::remove(backupPath); // We have it in memory now

    if (m_chunkUploadBuffer.isEmpty()) {
        setError(tr("Database backup is empty"));
        m_isUploading = false;
        emit uploadingChanged();
        emit syncingChanged();
        return;
    }

    m_chunkTotalSize = m_chunkUploadBuffer.size();
    m_chunkCurrentOffset = 0;
    m_chunkFileName = backupFileName;
    m_chunkRetryCount = 0;  // Reset retry count for new upload
    // Generate a clean ID for the file
    m_chunkUploadId = QUuid::createUuid().toString(QUuid::Id128); // "00112233..." hex string
    
    qDebug() << "Starting chunked upload:" << m_chunkFileName 
             << "Size:" << m_chunkTotalSize << "values, ID:" << m_chunkUploadId;

    uploadNextChunk();
}

void CloudSyncManager::uploadNextChunk()
{
    // Chunk size 5MB - Appwrite/S3 requires minimum 5MB for multipart upload parts
    // (except for the final part which can be smaller)
    const qint64 CHUNK_SIZE = 5 * 1024 * 1024; 

    qint64 remaining = m_chunkTotalSize - m_chunkCurrentOffset;
    if (remaining <= 0) {
        // Should have finished already
        return;
    }

    qint64 currentChunkSize = qMin(remaining, CHUNK_SIZE);
    qint64 endOffset = m_chunkCurrentOffset + currentChunkSize - 1;

    // Prepare content for this chunk
    QByteArray chunkData = m_chunkUploadBuffer.mid(m_chunkCurrentOffset, currentChunkSize);

    // Prepare multipart request
    QUrl url(m_endpoint + "/storage/buckets/" + m_bucketId + "/files");
    QNetworkRequest request(url);
    request.setRawHeader("X-Appwrite-Project", m_projectId.toUtf8());
    request.setRawHeader("X-Appwrite-Key", m_apiKey.toUtf8());
    
    // Content-Range header is critical for chunked upload
    // Format: bytes start-end/total
    QString contentRange = QString("bytes %1-%2/%3")
                               .arg(m_chunkCurrentOffset)
                               .arg(endOffset)
                               .arg(m_chunkTotalSize);
    request.setRawHeader("Content-Range", contentRange.toUtf8());

    QHttpMultiPart *multiPart = new QHttpMultiPart(QHttpMultiPart::FormDataType);

    // File ID - must be sent with every chunk
    QHttpPart fileIdPart;
    fileIdPart.setHeader(QNetworkRequest::ContentDispositionHeader, 
                         QVariant("form-data; name=\"fileId\""));
    fileIdPart.setBody(m_chunkUploadId.toUtf8());
    multiPart->append(fileIdPart);

    // File content chunk
    QHttpPart filePart;
    filePart.setHeader(QNetworkRequest::ContentDispositionHeader,
                       QVariant(QString("form-data; name=\"file\"; filename=\"%1\"").arg(m_chunkFileName)));
    filePart.setHeader(QNetworkRequest::ContentTypeHeader, QVariant("application/octet-stream"));
    filePart.setBody(chunkData);
    multiPart->append(filePart);

    qDebug() << "Uploading chunk:" << contentRange << "Size:" << currentChunkSize;

    QNetworkReply *reply = m_networkManager->post(request, multiPart);
    multiPart->setParent(reply);

    connect(reply, &QNetworkReply::uploadProgress, this, &CloudSyncManager::onUploadProgress);
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        onChunkUploadFinished(reply);
    });
}

void CloudSyncManager::onChunkUploadFinished(QNetworkReply *reply)
{
    reply->deleteLater();

    if (reply->error() != QNetworkReply::NoError) {
        QString error = reply->errorString();
        // Read body for details
        QByteArray response = reply->readAll();
        
        // Check for retriable HTTP errors (502, 503, 504)
        int httpStatus = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        bool isRetriable = (httpStatus == 502 || httpStatus == 503 || httpStatus == 504 ||
                           reply->error() == QNetworkReply::TemporaryNetworkFailureError ||
                           reply->error() == QNetworkReply::NetworkSessionFailedError);
        
        if (isRetriable && m_chunkRetryCount < MAX_CHUNK_RETRIES) {
            m_chunkRetryCount++;
            int delayMs = 1000 * (1 << m_chunkRetryCount);  // Exponential backoff: 2s, 4s, 8s
            qWarning() << "Chunk upload failed (retriable), retry" << m_chunkRetryCount 
                       << "of" << MAX_CHUNK_RETRIES << "in" << delayMs << "ms:" << error;
            QTimer::singleShot(delayMs, this, &CloudSyncManager::retryCurrentChunk);
            return;
        }
        
        qWarning() << "Chunk upload failed:" << error << response;
        setError(tr("Upload failed: %1").arg(error));
        m_isUploading = false;
        m_chunkUploadBuffer.clear();
        emit uploadingChanged();
        emit syncingChanged();
        return;
    }

    // Success - reset retry count for next chunk
    m_chunkRetryCount = 0;
    
    // Calculate new offset
    // Should be consistent with what we sent
    // We can parse response to verify, but relying on our offset is standard logic
    const qint64 CHUNK_SIZE = 5 * 1024 * 1024;
    qint64 previousChunkSize = qMin(m_chunkTotalSize - m_chunkCurrentOffset, CHUNK_SIZE);
    
    m_chunkCurrentOffset += previousChunkSize;
    m_uploadProgress = (double)m_chunkCurrentOffset / m_chunkTotalSize;
    emit uploadProgressChanged();

    if (m_chunkCurrentOffset >= m_chunkTotalSize) {
        // All done!
        qDebug() << "Upload complete!";
        onUploadFinished(reply); // Trigger final success logic (parse response etc)
        m_chunkUploadBuffer.clear();
    } else {
        // Upload next chunk
        uploadNextChunk();
    }
}

void CloudSyncManager::retryCurrentChunk()
{
    qDebug() << "Retrying chunk upload at offset:" << m_chunkCurrentOffset;
    uploadNextChunk();
}

void CloudSyncManager::onUploadProgress(qint64 bytesSent, qint64 bytesTotal)
{
    if (bytesTotal > 0) {
        m_uploadProgress = static_cast<double>(bytesSent) / static_cast<double>(bytesTotal);
        emit uploadProgressChanged();
    }
}

void CloudSyncManager::onUploadFinished(QNetworkReply *reply)
{
    m_isUploading = false;
    m_uploadProgress = 0.0;
    emit uploadingChanged();
    emit syncingChanged();
    emit uploadProgressChanged();

    if (reply->error() != QNetworkReply::NoError) {
        QString errorBody = QString::fromUtf8(reply->readAll());
        setError(tr("Upload failed: %1 - %2").arg(reply->errorString()).arg(errorBody));
        reply->deleteLater();
        return;
    }

    QByteArray data = reply->readAll();
    QJsonDocument doc = QJsonDocument::fromJson(data);
    QJsonObject obj = doc.object();

    QString fileId = obj["$id"].toString();
    
    // Update last sync time
    m_lastSyncTime = QDateTime::currentDateTime().toString(Qt::ISODate);
    QSettings settings;
    settings.setValue("cloud/lastSyncTime", m_lastSyncTime);
    emit lastSyncTimeChanged();

    qDebug() << "Upload complete. File ID:" << fileId;
    emit uploadComplete(fileId);

    reply->deleteLater();
}

// ============ LIST CLOUD BACKUPS ============

void CloudSyncManager::listCloudBackups()
{
    if (!isConfigured()) {
        setError(tr("Cloud sync not configured. Please set API key."));
        return;
    }

    clearError();

    QString path = QString("/storage/buckets/%1/files").arg(m_bucketId);
    QNetworkRequest request = createRequest(path);

    QNetworkReply *reply = m_networkManager->get(request);
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        onListFinished(reply);
    });
}

void CloudSyncManager::onListFinished(QNetworkReply *reply)
{
    if (reply->error() != QNetworkReply::NoError) {
        QString errorBody = QString::fromUtf8(reply->readAll());
        setError(tr("Failed to list backups: %1 - %2").arg(reply->errorString()).arg(errorBody));
        reply->deleteLater();
        return;
    }

    QByteArray data = reply->readAll();
    QJsonDocument doc = QJsonDocument::fromJson(data);
    QJsonObject obj = doc.object();
    QJsonArray files = obj["files"].toArray();

    QVariantList backups;
    for (const QJsonValue &val : files) {
        QJsonObject file = val.toObject();
        
        // Only include .db files (our database backups)
        QString name = file["name"].toString();
        if (!name.endsWith(".db")) {
            continue;
        }

        QVariantMap backup;
        backup["id"] = file["$id"].toString();
        backup["name"] = name;
        backup["size"] = file["sizeOriginal"].toVariant();
        backup["created"] = file["$createdAt"].toString();
        backup["mimeType"] = file["mimeType"].toString();
        backups.append(backup);
    }

    qDebug() << "Found" << backups.size() << "cloud backups";
    emit backupsListReady(backups);

    reply->deleteLater();
}

// ============ DOWNLOAD BACKUP ============

void CloudSyncManager::downloadBackup(const QString &fileId, const QString &fileName)
{
    if (m_isDownloading) {
        setError(tr("Download already in progress"));
        return;
    }

    if (!isConfigured()) {
        setError(tr("Cloud sync not configured. Please set API key."));
        return;
    }

    clearError();
    m_isDownloading = true;
    m_downloadProgress = 0.0;
    emit downloadingChanged();
    emit syncingChanged();
    emit downloadProgressChanged();

    // Prepare download path
    QString downloadDir = QStandardPaths::writableLocation(QStandardPaths::TempLocation);
    m_pendingDownloadPath = downloadDir + "/" + fileName;

    QString path = QString("/storage/buckets/%1/files/%2/download").arg(m_bucketId).arg(fileId);
    QNetworkRequest request = createRequest(path);
    request.setRawHeader("Content-Type", ""); // Remove JSON content type for download

    QNetworkReply *reply = m_networkManager->get(request);
    connect(reply, &QNetworkReply::downloadProgress, this, &CloudSyncManager::onDownloadProgress);
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        onDownloadFinished(reply);
    });
}

void CloudSyncManager::onDownloadProgress(qint64 bytesReceived, qint64 bytesTotal)
{
    if (bytesTotal > 0) {
        m_downloadProgress = static_cast<double>(bytesReceived) / static_cast<double>(bytesTotal);
        emit downloadProgressChanged();
    }
}

void CloudSyncManager::onDownloadFinished(QNetworkReply *reply)
{
    m_isDownloading = false;
    m_downloadProgress = 0.0;
    emit downloadingChanged();
    emit syncingChanged();
    emit downloadProgressChanged();

    if (reply->error() != QNetworkReply::NoError) {
        QString errorBody = QString::fromUtf8(reply->readAll());
        setError(tr("Download failed: %1 - %2").arg(reply->errorString()).arg(errorBody));
        reply->deleteLater();
        return;
    }

    // Save downloaded file
    QByteArray data = reply->readAll();
    QFile file(m_pendingDownloadPath);
    if (!file.open(QIODevice::WriteOnly)) {
        setError(tr("Failed to save downloaded backup"));
        reply->deleteLater();
        return;
    }
    file.write(data);
    file.close();

    // Restore from downloaded backup
    if (m_dbManager) {
        bool success = m_dbManager->restoreFromBackup(m_pendingDownloadPath);
        if (!success) {
            setError(tr("Failed to restore from downloaded backup"));
        } else {
            // Update last sync time
            m_lastSyncTime = QDateTime::currentDateTime().toString(Qt::ISODate);
            QSettings settings;
            settings.setValue("cloud/lastSyncTime", m_lastSyncTime);
            emit lastSyncTimeChanged();

            qDebug() << "Database restored from cloud backup:" << m_pendingDownloadPath;
            emit downloadComplete(m_pendingDownloadPath);
        }
    }

    // Cleanup temp file
    QFile::remove(m_pendingDownloadPath);
    m_pendingDownloadPath.clear();

    reply->deleteLater();
}

// ============ DELETE CLOUD BACKUP ============

void CloudSyncManager::deleteCloudBackup(const QString &fileId)
{
    if (!isConfigured()) {
        setError(tr("Cloud sync not configured. Please set API key."));
        return;
    }

    clearError();
    m_pendingDeleteId = fileId;

    QString path = QString("/storage/buckets/%1/files/%2").arg(m_bucketId).arg(fileId);
    QNetworkRequest request = createRequest(path);

    QNetworkReply *reply = m_networkManager->deleteResource(request);
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        onDeleteFinished(reply);
    });
}

void CloudSyncManager::onDeleteFinished(QNetworkReply *reply)
{
    QString fileId = m_pendingDeleteId;
    m_pendingDeleteId.clear();

    if (reply->error() != QNetworkReply::NoError) {
        QString errorBody = QString::fromUtf8(reply->readAll());
        setError(tr("Delete failed: %1 - %2").arg(reply->errorString()).arg(errorBody));
        reply->deleteLater();
        return;
    }

    qDebug() << "Cloud backup deleted:" << fileId;
    emit deleteComplete(fileId);

    reply->deleteLater();
}
