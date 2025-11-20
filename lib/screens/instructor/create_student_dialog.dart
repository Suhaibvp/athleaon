import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CreateStudentDialog extends StatefulWidget {
  final String? studentId;
  final Map<String, dynamic>? initialData;

  const CreateStudentDialog({
    super.key,
    this.studentId,
    this.initialData,
  });

  @override
  State<CreateStudentDialog> createState() => _CreateStudentDialogState();
}

class _CreateStudentDialogState extends State<CreateStudentDialog> {
  final _fullNameController = TextEditingController();
  final _dobController = TextEditingController();
  
  String? _selectedState;
  String? _selectedLanguage;
  String _selectedEvent = 'Pistol 10 m';
  bool _isLoading = false;

  // All Indian States and Union Territories
  final List<String> _indianStates = [
    'Andhra Pradesh',
    'Arunachal Pradesh',
    'Assam',
    'Bihar',
    'Chhattisgarh',
    'Goa',
    'Gujarat',
    'Haryana',
    'Himachal Pradesh',
    'Jharkhand',
    'Karnataka',
    'Kerala',
    'Madhya Pradesh',
    'Maharashtra',
    'Manipur',
    'Meghalaya',
    'Mizoram',
    'Nagaland',
    'Odisha',
    'Punjab',
    'Rajasthan',
    'Sikkim',
    'Tamil Nadu',
    'Telangana',
    'Tripura',
    'Uttar Pradesh',
    'Uttarakhand',
    'West Bengal',
    'Andaman and Nicobar Islands',
    'Chandigarh',
    'Dadra and Nagar Haveli and Daman and Diu',
    'Delhi',
    'Jammu and Kashmir',
    'Ladakh',
    'Lakshadweep',
    'Puducherry',
  ];

  // All Indian Languages
  final List<String> _indianLanguages = [
    'Assamese',
    'Bengali',
    'Bodo',
    'Dogri',
    'English',
    'Gujarati',
    'Hindi',
    'Kannada',
    'Kashmiri',
    'Konkani',
    'Maithili',
    'Malayalam',
    'Manipuri (Meitei)',
    'Marathi',
    'Nepali',
    'Odia',
    'Punjabi',
    'Sanskrit',
    'Santali',
    'Sindhi',
    'Tamil',
    'Telugu',
    'Urdu',
  ];

  @override
  void initState() {
    super.initState();
    
    if (widget.initialData != null) {
      _fullNameController.text = widget.initialData!['fullName'] ?? '';
      _dobController.text = widget.initialData!['dateOfBirth']?.toString() ?? '';
      _selectedState = widget.initialData!['state'];
      _selectedLanguage = widget.initialData!['languagesKnown'];
      _selectedEvent = widget.initialData!['preferredEvent'] ?? 'Pistol 10 m';
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  Future<void> _createStudent() async {
    if (_fullNameController.text.trim().isEmpty) {
      _showError('Please enter student name');
      return;
    }

    if (_selectedState == null) {
      _showError('Please select a state');
      return;
    }

    if (_selectedLanguage == null) {
      _showError('Please select a language');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final currentCoachId = FirebaseAuth.instance.currentUser!.uid;
      
      await FirebaseFirestore.instance
          .collection('coach_students')
          .add({
        'fullName': _fullNameController.text.trim(),
        'dateOfBirth': _dobController.text.trim(),
        'state': _selectedState,
        'languagesKnown': _selectedLanguage,
        'preferredEvent': _selectedEvent,
        'coachId': currentCoachId,
        'createdBy': 'coach',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      
      Navigator.pop(context, true);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Student created successfully'),
          backgroundColor: Color(0xFF4CAF50),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _showError('Error creating student: $e');
      setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFD32F2F),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF2A2A2A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Student Creation',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Full Name
              _buildLabel('Full Name'),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _fullNameController,
                hintText: 'Enter full name',
              ),

              const SizedBox(height: 16),

              // Date of Birth
              _buildLabel('Date of Birth'),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _dobController,
                hintText: 'Select date',
                readOnly: true,
                suffixIcon: const Icon(Icons.calendar_today, color: Colors.white, size: 18),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(1950),
                    lastDate: DateTime.now(),
                    builder: (context, child) {
                      return Theme(
                        data: ThemeData.dark().copyWith(
                          colorScheme: const ColorScheme.dark(
                            primary: Color(0xFFD32F2F),
                            surface: Color(0xFF2A2A2A),
                          ),
                        ),
                        child: child!,
                      );
                    },
                  );
                  if (date != null) {
                    _dobController.text = '${date.day}/${date.month}/${date.year}';
                  }
                },
              ),

              const SizedBox(height: 16),

              // State Dropdown
              _buildLabel('State'),
              const SizedBox(height: 8),
              _buildDropdown(
                value: _selectedState,
                hint: 'Select state',
                items: _indianStates,
                onChanged: (value) {
                  setState(() => _selectedState = value);
                },
              ),

              const SizedBox(height: 16),

              // Language Dropdown
              _buildLabel('Language Known'),
              const SizedBox(height: 8),
              _buildDropdown(
                value: _selectedLanguage,
                hint: 'Select language',
                items: _indianLanguages,
                onChanged: (value) {
                  setState(() => _selectedLanguage = value);
                },
              ),

              const SizedBox(height: 16),

              // Events Dropdown
              _buildLabel('Events'),
              const SizedBox(height: 8),
              _buildDropdown(
                value: _selectedEvent,
                hint: 'Select event',
                items: ['Pistol 10 m', 'Rifle 10 m'],
                onChanged: (value) {
                  setState(() => _selectedEvent = value!);
                },
              ),

              const SizedBox(height: 24),

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFD32F2F),
                        side: const BorderSide(color: Color(0xFFD32F2F)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _createStudent,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD32F2F),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Save',
                              style: TextStyle(color: Colors.white),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    bool readOnly = false,
    Widget? suffixIcon,
    VoidCallback? onTap,
  }) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      readOnly: readOnly,
      onTap: onTap,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
        filled: true,
        fillColor: const Color(0xFF1A1A1A),
        suffixIcon: suffixIcon,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFD32F2F)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFD32F2F)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFD32F2F), width: 2),
        ),
      ),
    );
  }

Widget _buildDropdown({
  required String? value,
  required String hint,
  required List<String> items,
  required void Function(String?) onChanged,
}) {
  return DropdownButtonFormField<String>(
    value: value,
    isExpanded: true, // ✅ Allow text to fill width
    dropdownColor: const Color(0xFF1A1A1A),
    style: const TextStyle(color: Colors.white, fontSize: 14), // ✅ Smaller font
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
      filled: true,
      fillColor: const Color(0xFF1A1A1A),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFD32F2F)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFD32F2F)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFD32F2F), width: 2),
      ),
    ),
    items: items
        .map((item) => DropdownMenuItem(
              value: item,
              child: Text(
                item,
                overflow: TextOverflow.ellipsis, // ✅ Truncate long text
                maxLines: 1,
              ),
            ))
        .toList(),
    onChanged: onChanged,
  );
}

}
