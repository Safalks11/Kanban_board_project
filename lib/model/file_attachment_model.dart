import 'dart:io';

enum AttachmentStatus { pending, uploading, uploaded, failed }

class FileAttachment {
  final String id;
  final String fileName;
  final String? localPath;
  final String? downloadUrl;
  final int fileSize;
  final String mimeType;
  final AttachmentStatus status;
  final double? uploadProgress;
  final String? errorMessage;
  final DateTime createdAt;

  const FileAttachment({
    required this.id,
    required this.fileName,
    this.localPath,
    this.downloadUrl,
    required this.fileSize,
    required this.mimeType,
    this.status = AttachmentStatus.pending,
    this.uploadProgress,
    this.errorMessage,
    required this.createdAt,
  });

  FileAttachment copyWith({
    String? id,
    String? fileName,
    String? localPath,
    String? downloadUrl,
    int? fileSize,
    String? mimeType,
    AttachmentStatus? status,
    double? uploadProgress,
    String? errorMessage,
    DateTime? createdAt,
  }) {
    return FileAttachment(
      id: id ?? this.id,
      fileName: fileName ?? this.fileName,
      localPath: localPath ?? this.localPath,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      fileSize: fileSize ?? this.fileSize,
      mimeType: mimeType ?? this.mimeType,
      status: status ?? this.status,
      uploadProgress: uploadProgress ?? this.uploadProgress,
      errorMessage: errorMessage ?? this.errorMessage,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fileName': fileName,
      'localPath': localPath,
      'downloadUrl': downloadUrl,
      'fileSize': fileSize,
      'mimeType': mimeType,
      'status': status.name,
      'uploadProgress': uploadProgress,
      'errorMessage': errorMessage,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory FileAttachment.fromJson(Map<String, dynamic> json) {
    return FileAttachment(
      id: json['id'] as String,
      fileName: json['fileName'] as String,
      localPath: json['localPath'] as String?,
      downloadUrl: json['downloadUrl'] as String?,
      fileSize: json['fileSize'] as int,
      mimeType: json['mimeType'] as String,
      status: AttachmentStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => AttachmentStatus.pending,
      ),
      uploadProgress: json['uploadProgress'] as double?,
      errorMessage: json['errorMessage'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  factory FileAttachment.fromFile(File file) {
    return FileAttachment(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      fileName: file.path.split('/').last,
      localPath: file.path,
      fileSize: file.lengthSync(),
      mimeType: _getMimeType(file.path),
      createdAt: DateTime.now(),
    );
  }

  static String _getMimeType(String filePath) {
    final extension = filePath.split('.').last.toLowerCase();
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      default:
        return 'application/octet-stream';
    }
  }

  String get fileSizeFormatted {
    if (fileSize < 1024) {
      return '$fileSize B';
    } else if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }

  bool get isImage {
    return mimeType.startsWith('image/');
  }

  bool get isPdf {
    return mimeType == 'application/pdf';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FileAttachment &&
        other.id == id &&
        other.fileName == fileName &&
        other.localPath == localPath &&
        other.downloadUrl == downloadUrl &&
        other.fileSize == fileSize &&
        other.mimeType == mimeType &&
        other.status == status &&
        other.uploadProgress == uploadProgress &&
        other.errorMessage == errorMessage &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        fileName.hashCode ^
        localPath.hashCode ^
        downloadUrl.hashCode ^
        fileSize.hashCode ^
        mimeType.hashCode ^
        status.hashCode ^
        uploadProgress.hashCode ^
        errorMessage.hashCode ^
        createdAt.hashCode;
  }

  @override
  String toString() {
    return 'FileAttachment(id: $id, fileName: $fileName, status: $status)';
  }
}
