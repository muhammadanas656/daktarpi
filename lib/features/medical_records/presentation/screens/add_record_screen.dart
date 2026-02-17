import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../presentation/widgets/custom_snackbar.dart';
import '../../../../presentation/widgets/primary_button.dart';
import '../../data/medical_record.dart';
import '../../data/medical_record_repository.dart';

class AddRecordScreen extends StatefulWidget {
  final MedicalRecord? recordToEdit;
  const AddRecordScreen({super.key, this.recordToEdit});

  @override
  State<AddRecordScreen> createState() => _AddRecordScreenState();
}

class _AddRecordScreenState extends State<AddRecordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _repository = MedicalRecordRepository();
  final _nameController = TextEditingController();
  
  String _selectedType = 'Report';
  DateTime _selectedDate = DateTime.now();
  final List<File> _selectedFiles = []; // Combined list for images and docs
  List<String> _existingFilePaths = []; // For edit mode
  final _picker = ImagePicker();
  bool _isLoading = false;

  final List<Map<String, dynamic>> _recordTypes = [
    {'type': 'Report', 'icon': Icons.analytics_outlined},
    {'type': 'Prescription', 'icon': Icons.medical_services_outlined},
    {'type': 'Invoice', 'icon': Icons.receipt_long_outlined},
  ];

  @override
  void initState() {
    super.initState();
    if (widget.recordToEdit != null) {
      final record = widget.recordToEdit!;
      _nameController.text = record.recordFor;
      _selectedType = record.recordType;
      _selectedDate = record.recordDate;
      _existingFilePaths = List.from(record.fileUrls);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage();
      if (images.isNotEmpty) {
        setState(() {
          _selectedFiles.addAll(images.map((x) => File(x.path)));
        });
      }
    } catch (e) {
      if (mounted) {
        CustomSnackbar.showError(context, "Failed to pick images: $e");
      }
    }
  }

  Future<void> _takePhoto() async {
    try {
      final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
      if (photo != null) {
        setState(() {
          _selectedFiles.add(File(photo.path));
        });
      }
    } catch (e) {
      if (mounted) {
        CustomSnackbar.showError(context, "Failed to capture photo: $e");
      }
    }
  }

  Future<void> _pickFiles() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'png', 'jpeg'],
      );

      if (result != null) {
        setState(() {
          _selectedFiles.addAll(result.paths.map((path) => File(path!)).toList());
        });
      }
    } catch (e) {
      if (mounted) {
        CustomSnackbar.showError(context, "Failed to pick files: $e");
      }
    }
  }

  Future<void> _showImagePickerModal() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text("Add a record", style: AppTextStyles.h2),
              const SizedBox(height: 24),
              _buildModalOption(Icons.camera_alt, "Take a photo", _takePhoto),
              _buildModalOption(Icons.photo_library, "Upload from gallery", _pickImages),
              _buildModalOption(Icons.folder_open, "Browse files", _pickFiles), 
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModalOption(IconData icon, String label, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: AppColors.textLight),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
      contentPadding: EdgeInsets.zero,
    );
  }


  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: AppTheme.lightTheme.copyWith(
            colorScheme: const ColorScheme.light(primary: AppColors.primaryGreen),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _uploadRecord() async {
    if (!_formKey.currentState!.validate()) return;
    if(_selectedFiles.isEmpty && _existingFilePaths.isEmpty) {
      CustomSnackbar.showError(context, "Please select at least one file.");
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Upload NEW Files
      final newFilePaths = await _repository.uploadFiles(_selectedFiles);
      
      // 2. Combine with Existing Paths
      final allFilePaths = [..._existingFilePaths, ...newFilePaths];

      // 3. Save or Update Record
      if (widget.recordToEdit != null) {
        await _repository.updateRecord(
          id: widget.recordToEdit!.id,
          recordFor: _nameController.text.trim(),
          recordType: _selectedType,
          recordDate: _selectedDate,
          fileUrls: allFilePaths,
        );
         if (mounted) CustomSnackbar.showSuccess(context, "Record updated successfully!");
      } else {
        await _repository.addRecord(
          recordFor: _nameController.text.trim(),
          recordType: _selectedType,
          recordDate: _selectedDate,
          fileUrls: allFilePaths, // These are paths now
        );
         if (mounted) CustomSnackbar.showSuccess(context, "Record added successfully!");
      }

      if (mounted) {
        context.pop(true); // Return true to refresh list
      }
    } catch (e) {
      if (mounted) {
        CustomSnackbar.showError(context, "Error: $e");
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showFullImage(ImageProvider imageProvider) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(
               child: Image(image: imageProvider),
            ),
             IconButton(
               icon: const Icon(Icons.close, color: Colors.white),
               onPressed: () => Navigator.pop(context),
             ),
          ],
        ),
      ),
    );
  }

  void _showFilePreview(File file) {
     // For now just show "File selected" or maybe open if image. 
     // Since this is generic file picker, we might not be able to preview PDF inside app easily without plugin.
     // Let's just assume images for preview, others just show icon.
     final ext = file.path.split('.').last.toLowerCase();
     if(['jpg','jpeg','png'].contains(ext)) {
       _showFullImage(FileImage(file));
     } else {
       CustomSnackbar.showInfo(context, "Preview not available for this file type yet.");
     }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(widget.recordToEdit != null ? "Edit Record" : "Add Records", style: const TextStyle(color: AppColors.textDark, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.only(left: 16),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: AppColors.textDark, size: 20),
            onPressed: () => context.pop(),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Record For (MOVED UP)
              _buildLabel("Record for"),
              TextFormField(
                controller: _nameController,
                style: const TextStyle(
                  color: AppColors.primaryGreen,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
                decoration: const InputDecoration(
                  hintText: "Enter Name",
                  hintStyle: TextStyle(color: AppColors.textLight, fontWeight: FontWeight.normal),
                  suffixIcon: Icon(Icons.edit, color: AppColors.textLight, size: 18),
                  border: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.borderColor)),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.borderColor)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primaryGreen)),
                  contentPadding: EdgeInsets.symmetric(horizontal: 0, vertical: 8),
                ),
                validator: (value) => value == null || value.isEmpty ? "Required" : null,
              ),
              const SizedBox(height: 24),

              // 2. Type of Record
              _buildLabel("Type of record"),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: _recordTypes.map((item) {
                  final type = item['type'] as String;
                  final icon = item['icon'] as IconData;
                  final isSelected = _selectedType == type;
                  
                  return GestureDetector(
                    onTap: () {
                      setState(() => _selectedType = type);
                      _showImagePickerModal();
                    },
                    child: Column(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.primaryGreen : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            icon,
                            color: isSelected ? Colors.white : AppColors.textLight,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          type,
                          style: TextStyle(
                            color: isSelected ? AppColors.primaryGreen : AppColors.textLight,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // 3. File Upload Component (Moved HERE)
              SizedBox(
                height: 120,
                child: Row(
                  children: [
                    if(_selectedFiles.isNotEmpty || _existingFilePaths.isNotEmpty)
                      Expanded(
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            // Existing Files
                             ..._existingFilePaths.asMap().entries.map((entry) {
                                  final index = entry.key;
                                  final path = entry.value;
                                  final isImage = ['jpg','jpeg','png'].contains(path.split('.').last.toLowerCase());
                                  
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 12),
                                    child: Stack(
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(12),
                                          child: FutureBuilder<String>(
                                            future: _repository.getSignedUrl(path),
                                            builder: (context, snapshot) {
                                              if (!snapshot.hasData) return const SizedBox(width: 100, height: 120, child: Center(child: CircularProgressIndicator()));
                                              
                                               if (isImage) {
                                                 return GestureDetector(
                                                  onTap: () => _showFullImage(NetworkImage(snapshot.data!)),
                                                  child: Image.network(
                                                    snapshot.data!,
                                                    width: 100,
                                                    height: 120,
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (_,__,___) => const Icon(Icons.broken_image),
                                                  ),
                                                 );
                                               } else {
                                                 return Container(
                                                   width: 100,
                                                   height: 120,
                                                   color: Colors.grey[100],
                                                   child: const Center(child: Icon(Icons.insert_drive_file, color: AppColors.primaryGreen, size: 40)),
                                                 );
                                               }
                                            },
                                          ),
                                        ),
                                        Positioned(
                                          top: 5,
                                          right: 5,
                                          child: GestureDetector(
                                            onTap: () => setState(() => _existingFilePaths.removeAt(index)),
                                            child: const CircleAvatar(
                                              radius: 10,
                                              backgroundColor: Colors.red,
                                              child: Icon(Icons.close, size: 12, color: Colors.white),
                                            ),
                                          ),
                                        )
                                      ],
                                    ),
                                  );
                             }),

                             // New Files
                              ..._selectedFiles.asMap().entries.map((entry) {
                                  final index = entry.key;
                                  final file = entry.value;
                                  final isImage = ['jpg','jpeg','png'].contains(file.path.split('.').last.toLowerCase());

                                  return Padding(
                                    padding: const EdgeInsets.only(right: 12),
                                    child: Stack(
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(12),
                                          child: GestureDetector(
                                            onTap: () => _showFilePreview(file),
                                            child: isImage ? Image.file(
                                              file,
                                              width: 100,
                                              height: 120,
                                              fit: BoxFit.cover,
                                            ) : Container(
                                                width: 100,
                                                height: 120,
                                                color: Colors.grey[100],
                                                child: const Center(child: Icon(Icons.insert_drive_file, color: AppColors.primaryGreen, size: 40)),
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          top: 5,
                                          right: 5,
                                          child: GestureDetector(
                                            onTap: () => setState(() => _selectedFiles.removeAt(index)),
                                            child: const CircleAvatar(
                                              radius: 10,
                                              backgroundColor: Colors.red,
                                              child: Icon(Icons.close, size: 12, color: Colors.white),
                                            ),
                                          ),
                                        )
                                      ],
                                    ),
                                  );
                             }),
                          ],
                        ),
                      ),
                    
                    if(_selectedFiles.isNotEmpty || _existingFilePaths.isNotEmpty) const SizedBox(width: 12),

                    GestureDetector(
                      onTap: _showImagePickerModal,
                      child: Container(
                        width: 100,
                        height: 120,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0F2F1), // Very light teal
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.add, color: AppColors.primaryGreen, size: 32),
                            SizedBox(height: 8),
                            Text(
                              "Add more\nfiles",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.primaryGreen,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),


              // 4. Date Picker
              _buildLabel("Record created on"),
              GestureDetector(
                onTap: () => _selectDate(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: const BoxDecoration(
                     border: Border(bottom: BorderSide(color: AppColors.borderColor))
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        DateFormat('dd MMM, yyyy').format(_selectedDate),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryGreen,
                        ),
                      ),
                      const Icon(Icons.edit, color: AppColors.textLight, size: 18),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(24.0),
        child: PrimaryButton(
          label: _isLoading ? "Processing..." : (widget.recordToEdit != null ? "Update record" : "Upload record"),
          onTap: _isLoading ? () {} : _uploadRecord, 
          isLoading: _isLoading,
        ),
      ),
    );
  }

  Widget _buildLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: AppColors.textDark,
      ),
    );
  }
}
