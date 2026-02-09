#ifndef CLOUDSYNCMANAGER_H
#define CLOUDSYNCMANAGER_H

#include <QObject>
#include <QString>
#include <QVariant>
#include <QList>
#include <QMap>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QDateTime>
#include <QTimer>

class DatabaseManager;

/**
 * @brief CloudSyncManager - Handles cloud backup/restore via Appwrite Storage
 *
 * Provides functionality for:
 * - Uploading database backups to Appwrite Cloud Storage
 * - Listing available cloud backups
 * - Downloading and restoring from cloud backups
 * - Deleting cloud backups
 */
class CloudSyncManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool isUploading READ isUploading NOTIFY uploadingChanged)
    Q_PROPERTY(bool isDownloading READ isDownloading NOTIFY downloadingChanged)
    Q_PROPERTY(bool isSyncing READ isSyncing NOTIFY syncingChanged)
    Q_PROPERTY(bool isConfigured READ isConfigured NOTIFY configuredChanged)
    Q_PROPERTY(QString lastSyncTime READ lastSyncTime NOTIFY lastSyncTimeChanged)
    Q_PROPERTY(QString errorMessage READ errorMessage NOTIFY errorChanged)
    Q_PROPERTY(QString bucketId READ bucketId WRITE setBucketId NOTIFY bucketIdChanged)
    Q_PROPERTY(double uploadProgress READ uploadProgress NOTIFY uploadProgressChanged)
    Q_PROPERTY(double downloadProgress READ downloadProgress NOTIFY downloadProgressChanged)

public:
    explicit CloudSyncManager(DatabaseManager *dbManager, QObject *parent = nullptr);
    ~CloudSyncManager();

    // Properties
    bool isUploading() const { return m_isUploading; }
    bool isDownloading() const { return m_isDownloading; }
    bool isSyncing() const { return m_isUploading || m_isDownloading; }
    QString lastSyncTime() const { return m_lastSyncTime; }
    QString errorMessage() const { return m_errorMessage; }
    double uploadProgress() const { return m_uploadProgress; }
    double downloadProgress() const { return m_downloadProgress; }

    // Cloud operations
    Q_INVOKABLE void uploadDatabase();
    Q_INVOKABLE void listCloudBackups();
    Q_INVOKABLE void downloadBackup(const QString &fileId, const QString &fileName);
    Q_INVOKABLE void deleteCloudBackup(const QString &fileId);

    // Configuration
    Q_INVOKABLE void setApiKey(const QString &apiKey);
    Q_INVOKABLE void setBucketId(const QString &bucketId);
    Q_INVOKABLE QString bucketId() const { return m_bucketId; }
    Q_INVOKABLE bool isConfigured() const;

signals:
    void uploadingChanged();
    void downloadingChanged();
    void syncingChanged();
    void configuredChanged();
    void bucketIdChanged();
    void lastSyncTimeChanged();
    void errorChanged();
    void uploadProgressChanged();
    void downloadProgressChanged();

    void uploadComplete(const QString &fileId);
    void downloadComplete(const QString &localPath);
    void deleteComplete(const QString &fileId);
    void backupsListReady(const QVariantList &backups);
    void syncError(const QString &error);

private slots:
    void onUploadFinished(QNetworkReply *reply);
    void onListFinished(QNetworkReply *reply);
    void onDownloadFinished(QNetworkReply *reply);
    void onDeleteFinished(QNetworkReply *reply);
    void onUploadProgress(qint64 bytesSent, qint64 bytesTotal);
    void onDownloadProgress(qint64 bytesReceived, qint64 bytesTotal);

private:
    void setError(const QString &error);
    void clearError();
    QNetworkRequest createRequest(const QString &path) const;
    QString generateBackupFileName() const;

    DatabaseManager *m_dbManager;
    QNetworkAccessManager *m_networkManager;

    // Appwrite configuration
    QString m_endpoint;
    QString m_projectId;
    QString m_apiKey;
    QString m_bucketId;

    // State
    bool m_isUploading;
    bool m_isDownloading;
    QString m_lastSyncTime;
    QString m_errorMessage;
    double m_uploadProgress;
    double m_downloadProgress;

    // Pending operations
    QString m_pendingDownloadPath;
    QString m_pendingDeleteId;

    // chunked upload state
    void uploadNextChunk();
    void onChunkUploadFinished(QNetworkReply *reply);

    QByteArray m_chunkUploadBuffer;
    QString m_chunkUploadId;
    QString m_chunkFileName;
    qint64 m_chunkCurrentOffset;
    qint64 m_chunkTotalSize;
    
    // Retry logic for transient failures
    int m_chunkRetryCount;
    static const int MAX_CHUNK_RETRIES = 3;
    void retryCurrentChunk();

};

#endif // CLOUDSYNCMANAGER_H
