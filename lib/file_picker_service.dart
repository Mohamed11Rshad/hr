import 'dart:io';
import 'package:file_picker/file_picker.dart';

class FilePickerService {
  Future<File?> pickExcelFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls'],
    );
    return result != null ? File(result.files.single.path!) : null;
  }
}
