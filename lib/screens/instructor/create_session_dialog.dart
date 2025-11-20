import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/session_service.dart';

class CreateSessionDialog extends StatefulWidget {
  final String studentId;
  final String studentName;

  const CreateSessionDialog({
    super.key,
    required this.studentId,
    required this.studentName,
  });

  @override
  State<CreateSessionDialog> createState() => _CreateSessionDialogState();
}

class _CreateSessionDialogState extends State<CreateSessionDialog> {
  final SessionService _sessionService = SessionService();
  final TextEditingController _shotsController = TextEditingController();
  final TextEditingController _seriesNameController = TextEditingController(); // NEW
  
  String? _selectedEvent;
  bool _isLoading = false;

  final List<String> _events = [
    'ISSF 10m Air Pistol',
    'ISSF 10m Air Rifle',
  ];

  @override
  void dispose() {
    _shotsController.dispose();
    _seriesNameController.dispose(); // NEW
    super.dispose();
  }

  // Generate next series name if user doesn't provide one
  Future<String> _generateNextSeriesName() async {
    try {
      final counterRef = FirebaseFirestore.instance
          .collection('counters')
          .doc('student_${widget.studentId}_series');

      return await FirebaseFirestore.instance.runTransaction((transaction) async {
        final counterDoc = await transaction.get(counterRef);

        int nextNumber;
        if (!counterDoc.exists) {
          nextNumber = 1;
          transaction.set(counterRef, {'count': 1});
        } else {
          final currentCount = counterDoc.data()?['count'] ?? 0;
          nextNumber = currentCount + 1;
          transaction.update(counterRef, {'count': nextNumber});
        }

        return 'Series$nextNumber';
      });
    } catch (e) {
      print('Error generating series name: $e');
      return 'Series_${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  Future<void> _createSession() async {
    if (_selectedEvent == null) {
      _showMessage('Please select an event');
      return;
    }

    if (_shotsController.text.isEmpty) {
      _showMessage('Please enter shots per target');
      return;
    }

    final shots = int.tryParse(_shotsController.text);
    if (shots == null || shots <= 0) {
      _showMessage('Please enter a valid number of shots');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Use custom series name if provided, otherwise auto-generate
      String seriesName;
      if (_seriesNameController.text.trim().isNotEmpty) {
        seriesName = _seriesNameController.text.trim();
      } else {
        seriesName = await _generateNextSeriesName();
      }
      
      print('Creating session with name: $seriesName');
      
      await _sessionService.createSession(
        studentId: widget.studentId,
        studentName: widget.studentName,
        sessionName: seriesName,
        eventName: _selectedEvent!,
        shotsPerTarget: shots,
      );

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      print('Error creating session: $e');
      if (mounted) {
        _showMessage('Error creating session: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF2A2A2A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Series Creation',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
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

              const SizedBox(height: 24),

              // Series Name Input Field (NEW)
              const Text(
                'Series Name (Optional)',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _seriesNameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Enter custom series name or leave blank for auto-name',
                  hintStyle: const TextStyle(color: Colors.grey, fontSize: 12),
                  filled: true,
                  fillColor: const Color(0xFF1A1A1A),
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
              ),

              const SizedBox(height: 20),

              // Event Name Dropdown
              const Text(
                'Event Name',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFD32F2F)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedEvent,
                    hint: const Text(
                      'Select Event',
                      style: TextStyle(color: Colors.grey),
                    ),
                    isExpanded: true,
                    dropdownColor: const Color(0xFF2A2A2A),
                    icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    items: _events.map((event) {
                      return DropdownMenuItem(
                        value: event,
                        child: Text(event),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedEvent = value;
                      });
                    },
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Shots per Target
              const Text(
                'Shots per Target',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _shotsController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Enter number',
                  hintStyle: const TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: const Color(0xFF1A1A1A),
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
              ),

              const SizedBox(height: 24),

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFD32F2F),
                        side: const BorderSide(color: Color(0xFFD32F2F)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _createSession,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD32F2F),
                        padding: const EdgeInsets.symmetric(vertical: 14),
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
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
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

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF2A2A2A),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
