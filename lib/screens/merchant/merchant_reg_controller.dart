import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/business.dart';
import '../../models/profile.dart';
import '../../services/auth_service.dart';
import '../../services/data_service.dart';

/// Represents a picked interior photo with byte cache and upload state
class PickedMediaItem {
  final String fileName;
  final Uint8List bytes;
  String? url;
  bool isUploading;
  String? error;

  PickedMediaItem({
    required this.fileName,
    required this.bytes,
    this.url,
    this.isUploading = false,
    this.error,
  });
}

/// MerchantRegController manages multi-step merchant registration form state
/// across Steps 1 to 4 with resume-to-Step-2 capability.
class MerchantRegController extends ChangeNotifier {
  static const int maxFileSizeBytes = 5 * 1024 * 1024; // 5 MB

  // -------------------------------------------------------------
  // Step 1: Owner Basics (fields start empty)
  // -------------------------------------------------------------
  String fullName = '';
  String dob = '';
  DateTime? dobDateTime;
  String phone = '';
  String email = '';
  String password = '';
  bool isOtpVerified = false;

  // -------------------------------------------------------------
  // Step 2: Business Information (fields start empty)
  // -------------------------------------------------------------
  String businessName = '';
  String category = '';
  String bio = '';
  String municipality = '';
  String address = '';
  String contactPhone = '';
  String hours = '';
  double? lat;
  double? lng;
  bool isLocating = false;
  String? locationMessage;

  // Structured Operating Hours
  List<String> openDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  bool sameHoursDaily = true;
  String opensAt = '07:30';
  String closesAt = '21:00';

  // Store Photos & Branding
  Uint8List? logoBytes;
  String? logoFileName;
  String? logoUrl;
  bool uploadingLogo = false;
  String? logoError;

  Uint8List? coverBytes;
  String? coverFileName;
  String? coverUrl;
  bool uploadingCover = false;
  String? coverError;

  List<PickedMediaItem> interiorPhotos = [];
  bool uploadingInteriors = false;
  String? interiorsError;

  // -------------------------------------------------------------
  // Step 3: Permits & Verification Documents (merchant-docs)
  // -------------------------------------------------------------
  String? dtiFileName;
  String? dtiUrl;
  bool uploadingDti = false;

  String? birFileName;
  String? birUrl;
  bool uploadingBir = false;

  String? mayorFileName;
  String? mayorUrl;
  bool uploadingMayor = false;

  String? validIdFileName;
  String? validIdUrl;
  bool uploadingValidId = false;

  // -------------------------------------------------------------
  // Submission State
  // -------------------------------------------------------------
  bool isSubmitting = false;
  String? submitError;
  Business? createdBusiness;

  /// Resume state for returning merchant with existing profile but no business row
  void populateFromProfile(Profile profile, User? user) {
    if (profile.fullName != null && profile.fullName!.isNotEmpty) {
      fullName = profile.fullName!;
    }
    if (profile.phone != null && profile.phone!.isNotEmpty) {
      phone = profile.phone!;
      contactPhone = profile.phone!;
    }
    if (user?.email != null && user!.email!.isNotEmpty) {
      email = user.email!;
    }
    isOtpVerified = true;
    notifyListeners();
  }

  /// Request current GPS fix.
  Future<void> useCurrentLocation() async {
    isLocating = true;
    locationMessage = null;
    notifyListeners();

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse) {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 8),
          ),
        );
        lat = position.latitude;
        lng = position.longitude;
        locationMessage = 'Using GPS (${lat!.toStringAsFixed(4)}, ${lng!.toStringAsFixed(4)})';
      } else {
        locationMessage = 'Location permission denied. Please grant permission in Settings.';
      }
    } catch (e) {
      locationMessage = 'Location unavailable: ${e.toString().replaceAll('Exception:', '').trim()}';
    } finally {
      isLocating = false;
      notifyListeners();
    }
  }

  // -------------------------------------------------------------
  // Store Photos & Branding Media Actions
  // -------------------------------------------------------------

  /// Pick Logo (Square image, max 5MB)
  Future<void> pickLogo({required String userId, required DataService dataService}) async {
    logoError = null;
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      if (file.size > maxFileSizeBytes) {
        logoError = 'Logo exceeds 5 MB limit (${(file.size / (1024 * 1024)).toStringAsFixed(1)} MB)';
        notifyListeners();
        return;
      }

      Uint8List? bytes = file.bytes;
      if (bytes == null && file.path != null) {
        bytes = await File(file.path!).readAsBytes();
      }

      if (bytes == null) {
        logoError = 'Failed to read image data';
        notifyListeners();
        return;
      }

      logoBytes = bytes;
      logoFileName = file.name;
      logoUrl = null;
      notifyListeners();

      if (userId.isNotEmpty) {
        await uploadLogo(userId: userId, dataService: dataService);
      }
    } catch (e) {
      logoError = 'Error picking logo: ${e.toString().replaceAll('Exception:', '').trim()}';
      notifyListeners();
    }
  }

  Future<void> uploadLogo({required String userId, required DataService dataService}) async {
    if (logoBytes == null || logoFileName == null || userId.isEmpty) return;
    uploadingLogo = true;
    logoError = null;
    notifyListeners();

    try {
      final url = await dataService.uploadBusinessMedia(
        ownerId: userId,
        fileName: 'logo_${DateTime.now().millisecondsSinceEpoch}_$logoFileName',
        fileBytes: logoBytes!,
      );
      logoUrl = url;
    } catch (e) {
      logoError = 'Upload failed. Tap to retry.';
    } finally {
      uploadingLogo = false;
      notifyListeners();
    }
  }

  void removeLogo() {
    logoBytes = null;
    logoFileName = null;
    logoUrl = null;
    logoError = null;
    uploadingLogo = false;
    notifyListeners();
  }

  /// Pick Exterior Cover Photo (16:9 ratio, required, max 5MB)
  Future<void> pickCover({required String userId, required DataService dataService}) async {
    coverError = null;
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      if (file.size > maxFileSizeBytes) {
        coverError = 'Exterior photo exceeds 5 MB limit (${(file.size / (1024 * 1024)).toStringAsFixed(1)} MB)';
        notifyListeners();
        return;
      }

      Uint8List? bytes = file.bytes;
      if (bytes == null && file.path != null) {
        bytes = await File(file.path!).readAsBytes();
      }

      if (bytes == null) {
        coverError = 'Failed to read image data';
        notifyListeners();
        return;
      }

      coverBytes = bytes;
      coverFileName = file.name;
      coverUrl = null;
      notifyListeners();

      if (userId.isNotEmpty) {
        await uploadCover(userId: userId, dataService: dataService);
      }
    } catch (e) {
      coverError = 'Error picking photo: ${e.toString().replaceAll('Exception:', '').trim()}';
      notifyListeners();
    }
  }

  Future<void> uploadCover({required String userId, required DataService dataService}) async {
    if (coverBytes == null || coverFileName == null || userId.isEmpty) return;
    uploadingCover = true;
    coverError = null;
    notifyListeners();

    try {
      final url = await dataService.uploadBusinessMedia(
        ownerId: userId,
        fileName: 'cover_${DateTime.now().millisecondsSinceEpoch}_$coverFileName',
        fileBytes: coverBytes!,
      );
      coverUrl = url;
    } catch (e) {
      coverError = 'Upload failed. Tap to retry.';
    } finally {
      uploadingCover = false;
      notifyListeners();
    }
  }

  void removeCover() {
    coverBytes = null;
    coverFileName = null;
    coverUrl = null;
    coverError = null;
    uploadingCover = false;
    notifyListeners();
  }

  /// Pick Optional Interior Photos (up to 3, max 5MB each)
  Future<void> pickInteriorPhoto({required String userId, required DataService dataService}) async {
    interiorsError = null;
    if (interiorPhotos.length >= 3) {
      interiorsError = 'Maximum of 3 interior photos reached';
      notifyListeners();
      return;
    }

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      if (file.size > maxFileSizeBytes) {
        interiorsError = 'Interior photo exceeds 5 MB limit (${(file.size / (1024 * 1024)).toStringAsFixed(1)} MB)';
        notifyListeners();
        return;
      }

      Uint8List? bytes = file.bytes;
      if (bytes == null && file.path != null) {
        bytes = await File(file.path!).readAsBytes();
      }

      if (bytes == null) {
        interiorsError = 'Failed to read image data';
        notifyListeners();
        return;
      }

      final item = PickedMediaItem(
        fileName: file.name,
        bytes: bytes,
      );
      interiorPhotos.add(item);
      notifyListeners();

      if (userId.isNotEmpty) {
        await uploadInteriorItem(item: item, userId: userId, dataService: dataService);
      }
    } catch (e) {
      interiorsError = 'Error picking photo: ${e.toString().replaceAll('Exception:', '').trim()}';
      notifyListeners();
    }
  }

  Future<void> uploadInteriorItem({
    required PickedMediaItem item,
    required String userId,
    required DataService dataService,
  }) async {
    if (userId.isEmpty) return;
    item.isUploading = true;
    item.error = null;
    notifyListeners();

    try {
      final url = await dataService.uploadBusinessMedia(
        ownerId: userId,
        fileName: 'interior_${DateTime.now().millisecondsSinceEpoch}_${item.fileName}',
        fileBytes: item.bytes,
      );
      item.url = url;
    } catch (e) {
      item.error = 'Upload failed. Tap to retry.';
    } finally {
      item.isUploading = false;
      notifyListeners();
    }
  }

  void removeInteriorPhoto(int index) {
    if (index >= 0 && index < interiorPhotos.length) {
      interiorPhotos.removeAt(index);
      interiorsError = null;
      notifyListeners();
    }
  }

  // -------------------------------------------------------------
  // Permits & Verification Documents (merchant-docs bucket)
  // -------------------------------------------------------------

  Future<void> pickAndUploadDocument({
    required String docType, // 'dti', 'bir', 'mayor', 'valid_id'
    required String userId,
    required DataService dataService,
  }) async {
    try {
      _setDocUploading(docType, true);

      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        _setDocUploading(docType, false);
        return;
      }

      final file = result.files.first;
      final fileName = file.name;
      Uint8List? fileBytes = file.bytes;

      if (fileBytes == null && file.path != null) {
        fileBytes = await File(file.path!).readAsBytes();
      }

      if (fileBytes != null && userId.isNotEmpty) {
        try {
          final url = await dataService.uploadMerchantPermit(
            ownerId: userId,
            fileName: '${docType}_$fileName',
            fileBytes: fileBytes,
          );
          _setDocSuccess(docType, fileName, url);
        } catch (_) {
          _setDocSuccess(docType, fileName, null);
        }
      } else {
        _setDocSuccess(docType, fileName, null);
      }
    } catch (_) {
      _setDocUploading(docType, false);
    }
  }

  void _setDocUploading(String type, bool value) {
    switch (type) {
      case 'dti':
        uploadingDti = value;
        break;
      case 'bir':
        uploadingBir = value;
        break;
      case 'mayor':
        uploadingMayor = value;
        break;
      case 'valid_id':
        uploadingValidId = value;
        break;
    }
    notifyListeners();
  }

  void _setDocSuccess(String type, String fileName, String? url) {
    switch (type) {
      case 'dti':
        dtiFileName = fileName;
        dtiUrl = url;
        uploadingDti = false;
        break;
      case 'bir':
        birFileName = fileName;
        birUrl = url;
        uploadingBir = false;
        break;
      case 'mayor':
        mayorFileName = fileName;
        mayorUrl = url;
        uploadingMayor = false;
        break;
      case 'valid_id':
        validIdFileName = fileName;
        validIdUrl = url;
        uploadingValidId = false;
        break;
    }
    notifyListeners();
  }

  // -------------------------------------------------------------
  // Submission
  // -------------------------------------------------------------

  /// Submit registration: creates unverified business row with media URLs.
  Future<bool> submitRegistration({
    required AuthService authService,
    required DataService dataService,
  }) async {
    isSubmitting = true;
    submitError = null;
    notifyListeners();

    try {
      String? uid = authService.currentUserId;

      if (uid == null || uid.isEmpty) {
        final authRes = await authService.signUpMerchant(
          email: email.trim(),
          password: password,
          fullName: fullName.trim(),
          phone: phone.trim(),
        );
        uid = authRes.user?.id;
      }

      if (uid == null || uid.isEmpty) {
        throw Exception('Could not determine merchant user ID');
      }

      if (lat == null || lng == null) {
        throw Exception('Store GPS coordinates required. Please acquire location.');
      }

      // Ensure cover photo is uploaded if bytes exist and url not yet generated
      if (coverBytes != null && (coverUrl == null || coverUrl!.isEmpty)) {
        await uploadCover(userId: uid, dataService: dataService);
      }

      // Ensure logo is uploaded if bytes exist and url not yet generated
      if (logoBytes != null && (logoUrl == null || logoUrl!.isEmpty)) {
        await uploadLogo(userId: uid, dataService: dataService);
      }

      // Ensure any pending interior photos are uploaded
      for (final item in interiorPhotos) {
        if (item.url == null || item.url!.isEmpty) {
          await uploadInteriorItem(item: item, userId: uid, dataService: dataService);
        }
      }

      final formattedHours = hours.trim().isNotEmpty
          ? hours.trim()
          : '${openDays.join(', ')}: $opensAt – $closesAt';

      final newBusiness = Business(
        id: '', // Generated by Postgres
        ownerId: uid,
        name: businessName.trim(),
        category: category,
        bio: bio.trim(),
        address: address.trim(),
        phone: contactPhone.trim().isEmpty ? phone.trim() : contactPhone.trim(),
        hours: formattedHours,
        lat: lat!,
        lng: lng!,
        radiusMeters: 1500.0,
        rating: 5.0,
        verified: false,
        coverUrl: coverUrl,
        logoUrl: logoUrl,
        interiorUrls: interiorPhotos.map((p) => p.url).whereType<String>().toList(),
        openDays: openDays,
        opensAt: opensAt,
        closesAt: closesAt,
        createdAt: DateTime.now().toUtc(),
      );

      final created = await dataService.createBusiness(newBusiness);
      createdBusiness = created;
      isSubmitting = false;
      notifyListeners();
      return true;
    } catch (e) {
      isSubmitting = false;
      submitError = e.toString().replaceAll('Exception:', '').trim();
      notifyListeners();
      return false;
    }
  }
}
