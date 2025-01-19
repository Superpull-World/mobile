import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../services/workflow_service.dart';
import '../services/wallet_service.dart';
import '../services/auth_service.dart';
import '../providers/token_provider.dart';
import '../providers/auctions_provider.dart';
import '../models/token_metadata.dart';

class CreateAuctionPage extends ConsumerStatefulWidget {
  const CreateAuctionPage({super.key});

  @override
  ConsumerState<CreateAuctionPage> createState() => _CreateAuctionPageState();
}

class _CreateAuctionPageState extends ConsumerState<CreateAuctionPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _minItemsController = TextEditingController();
  final _maxSupplyController = TextEditingController();
  final _workflowService = WorkflowService();
  final _walletService = WalletService();
  final _authService = AuthService();
  DateTime? _saleEndDate;
  XFile? _imageFile;
  bool _isLoading = false;
  String _submissionStatus = '';
  String? _selectedTokenMint;
  int? _tokenDecimals;
  String _priceFieldLabel = 'Price';

  @override
  void initState() {
    super.initState();
    // No need to load tokens here anymore as we'll use the provider
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _minItemsController.dispose();
    _maxSupplyController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() => _imageFile = image);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _saleEndDate ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFFEEFC42),
              onPrimary: Colors.black,
              surface: Colors.black,
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: const Color(0xFF1A1A1A),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _saleEndDate = picked);
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    if (_imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an image'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (_saleEndDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a sale end date'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (_selectedTokenMint == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a token'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _submissionStatus = 'Authenticating...';
    });

    try {
      // Get wallet address and JWT
      final walletAddress = await _walletService.getWalletAddress();
      final jwt = await _authService.getStoredJwt();
      
      if (jwt == null) {
        throw Exception('Please authenticate first');
      }

      // Check if JWT is valid
      if (!await _authService.isAuthenticated()) {
        setState(() {
          _submissionStatus = 'Re-authenticating...';
        });
        // Try to authenticate
        final newJwt = await _authService.authenticate();
        if (newJwt == null) {
          throw Exception('Authentication failed');
        }
      }

      setState(() {
        _submissionStatus = 'Uploading image...';
      });
      // TODO: Implement image upload service
      // For now we'll assume the image is uploaded and we get a URL
      final imageUrl = 'https://assets.superpull.world/placeholder.png'; // Replace with actual upload

      setState(() {
        _submissionStatus = 'Creating auction...';
      });

      await ref.read(auctionServiceProvider).createAuction(
        name: _nameController.text,
        description: _descriptionController.text,
        imageUrl: imageUrl,
        price: double.parse(_priceController.text),
        ownerAddress: walletAddress,
        maxSupply: int.parse(_maxSupplyController.text),
        minimumItems: int.parse(_minItemsController.text),
        deadline: _saleEndDate!,
        jwt: jwt,
        tokenMint: _selectedTokenMint!,
        onStatusUpdate: (status) {
          if (!mounted) return;
          setState(() {
            _submissionStatus = status;
          });
        },
      );

      if (!mounted) return;

      // Success case
      setState(() {
        _isLoading = false;
        _submissionStatus = '';
      });

      // Refresh auctions list
      ref.read(auctionsOperationsProvider).refresh();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Auction created successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create auction: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isLoading = false;
          _submissionStatus = '';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'Make it real',
          style: TextStyle(
            color: Color(0xFFEEFC42),
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(
          color: Color(0xFFEEFC42),
        ),
      ),
      body: _isLoading
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFEEFC42)),
                ),
                const SizedBox(height: 16),
                Text(
                  _submissionStatus,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          )
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      height: 200,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEFC42).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: _imageFile != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              File(_imageFile!.path),
                              fit: BoxFit.cover,
                            ),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_photo_alternate_outlined,
                                size: 48,
                                color: const Color(0xFFEEFC42).withOpacity(0.5),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Add Image',
                                style: TextStyle(
                                  color: const Color(0xFFEEFC42).withOpacity(0.5),
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _nameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      labelStyle: TextStyle(color: Colors.white70),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white24),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFFEEFC42)),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.red),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.red),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _descriptionController,
                    style: const TextStyle(color: Colors.white),
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      labelStyle: TextStyle(color: Colors.white70),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white24),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFFEEFC42)),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.red),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.red),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a description';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _priceController,
                    style: const TextStyle(color: Colors.white),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: _priceFieldLabel,
                      labelStyle: const TextStyle(color: Colors.white70),
                      enabledBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white24),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFFEEFC42)),
                      ),
                      errorBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.red),
                      ),
                      focusedErrorBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.red),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a price';
                      }
                      if (double.tryParse(value) == null) {
                        return 'Please enter a valid number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _minItemsController,
                          style: const TextStyle(color: Colors.white),
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Minimum Items',
                            labelStyle: TextStyle(color: Colors.white70),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.white24),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Color(0xFFEEFC42)),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.red),
                            ),
                            focusedErrorBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.red),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Required';
                            }
                            if (int.tryParse(value) == null) {
                              return 'Invalid number';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _maxSupplyController,
                          style: const TextStyle(color: Colors.white),
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Maximum Supply',
                            labelStyle: TextStyle(color: Colors.white70),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.white24),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Color(0xFFEEFC42)),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.red),
                            ),
                            focusedErrorBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.red),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Required';
                            }
                            if (int.tryParse(value) == null) {
                              return 'Invalid number';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: () => _selectDate(context),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: _saleEndDate != null
                            ? const Color(0xFFEEFC42)
                            : Colors.white24,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _saleEndDate != null
                              ? 'Sale ends on ${_saleEndDate!.toLocal().toString().split(' ')[0]}'
                              : 'Select sale end date',
                            style: TextStyle(
                              color: _saleEndDate != null
                                ? Colors.white
                                : Colors.white70,
                            ),
                          ),
                          Icon(
                            Icons.calendar_today,
                            color: _saleEndDate != null
                              ? const Color(0xFFEEFC42)
                              : Colors.white70,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildTokenSelector(),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _submitForm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEEFC42),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Dream it',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildTokenSelector() {
    final tokenState = ref.watch(tokenStateProvider);
    
    if (tokenState.isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFEEFC42)),
        ),
      );
    }
    
    if (tokenState.error != null) {
      return Center(
        child: Text(
          'Failed to load tokens: ${tokenState.error}',
          style: const TextStyle(color: Colors.red),
        ),
      );
    }
    
    final tokens = tokenState.tokens;
    if (tokens == null) {
      return const Center(
        child: Text(
          'No tokens available',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    return DropdownButtonFormField<String>(
      value: _selectedTokenMint,
      decoration: const InputDecoration(
        labelText: 'Token',
        labelStyle: TextStyle(color: Colors.white),
        border: OutlineInputBorder(),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.white24),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Color(0xFFEEFC42)),
        ),
      ),
      dropdownColor: Colors.black,
      style: const TextStyle(color: Colors.white),
      items: tokens.map((token) {
        return DropdownMenuItem<String>(
          value: token.mint,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 200),
            child: Text(
              '${token.symbol} (${token.mint})',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        );
      }).toList(),
      onChanged: (String? newValue) {
        if (newValue != null) {
          setState(() {
            _selectedTokenMint = newValue;
            _tokenDecimals = tokens
                .firstWhere((token) => token.mint == newValue)
                .decimals;
            
            // Update price field label with token symbol
            final symbol = tokens
                .firstWhere((token) => token.mint == newValue)
                .symbol;
            _priceFieldLabel = 'Price ($symbol)';
          });
        }
      },
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please select a token';
        }
        return null;
      },
    );
  }
} 