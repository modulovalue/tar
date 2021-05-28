import '../interface/file.dart';
import 'archive_mixin.dart';

class ArchiveImpl<ARCHIVEFILE extends ArchiveFile> with ArchiveMixin<ARCHIVEFILE> {
  @override
  final List<ARCHIVEFILE> files;

  @override
  final String? comment;

  ArchiveImpl([this.comment]) : files = [];
}
