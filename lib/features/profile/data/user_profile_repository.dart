/// Defines user profile repository in the profile feature's data layer.

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../../kyc/domain/kyc_models.dart';
import '../domain/bank_account_item.dart';
import '../domain/user_profile.dart';

/// Central singleton repository managing reactive synchronization and disk persistence
/// of the active user's profile and KYC document state.
///
/// Follows PaidiX architecture (single process-memory ValueNotifier,
/// identical to PaymentsRepositoryImpl, with resilient background disk caching).
class UserProfileRepository {
  /// Creates the singleton repository and seeds the built-in demo profiles.
  UserProfileRepository._internal() {
    _initDefaultUsers();
  }

  static final UserProfileRepository instance =
      UserProfileRepository._internal();
  /// Returns the shared repository instance used throughout the app process.
  factory UserProfileRepository() => instance;

  final Map<String, UserProfile> _registeredUsers = {};
  Directory? _storageDir;

  /// Seeds demo profiles and starts restoring any saved profile data.
  void _initDefaultUsers() {
    final def = UserProfile.defaultProfile();
    _registeredUsers[def.email.toLowerCase()] = def;
    // Canonical aliases for demo logins (e.g. kheroali66@gmail.com)
    _registeredUsers['kheroali66@gmail.com'] =
        def.copyWith(email: 'kheroali66@gmail.com');
    _registeredUsers['admin@paidix.com'] =
        def.copyWith(email: 'admin@paidix.com');

    // Attempt to restore previously saved profile details & documents from disk
    _loadPersistedDefaultUsers();
  }

  final ValueNotifier<UserProfile> profileNotifier =
      ValueNotifier<UserProfile>(UserProfile.defaultProfile());

  UserProfile get profile => profileNotifier.value;

  /// Remembers the current KYC onboarding step across activity pause/destruction
  KycStep activeKycStep = KycStep.personal;

  /// Normalizes an email into a filesystem-safe key for the user's storage folder.
  String _normalizeEmailKey(String email) {
    return email
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-zA-Z0-9_\-\.]'), '_');
  }

  /// Creates or retrieves the local directory used for profile persistence.
  Future<Directory?> _getStorageDir() async {
    if (_storageDir != null) return _storageDir;
    if (kIsWeb) return null;
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final dir = Directory('${appDir.path}/paidix_users');
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
      _storageDir = dir;
      return _storageDir;
    } catch (_) {
      try {
        final tmp = Directory('${Directory.systemTemp.path}/paidix_users');
        if (!tmp.existsSync()) {
          tmp.createSync(recursive: true);
        }
        _storageDir = tmp;
        return _storageDir;
      } catch (_) {
        return null;
      }
    }
  }

  /// Writes the profile and its identity-document data to the user's storage folder.
  Future<void> _persistUser(UserProfile user) async {
    if (user.email.isEmpty || kIsWeb) return;
    try {
      final baseDir = await _getStorageDir();
      if (baseDir == null) return;

      final key = _normalizeEmailKey(user.email);
      final userDir = Directory('${baseDir.path}/$key');
      if (!userDir.existsSync()) {
        userDir.createSync(recursive: true);
      }

      String? selfiePath = user.selfieFilePath;
      if (user.selfieBytes != null && user.selfieBytes!.isNotEmpty) {
        final f = File('${userDir.path}/selfie.jpg');
        await f.writeAsBytes(user.selfieBytes!, flush: true);
        selfiePath = f.path;
      }

      String? cnicFrontPath = user.cnicFrontFilePath;
      if (user.cnicFrontBytes != null && user.cnicFrontBytes!.isNotEmpty) {
        final f = File('${userDir.path}/cnic_front.jpg');
        await f.writeAsBytes(user.cnicFrontBytes!, flush: true);
        cnicFrontPath = f.path;
      }

      String? cnicBackPath = user.cnicBackFilePath;
      if (user.cnicBackBytes != null && user.cnicBackBytes!.isNotEmpty) {
        final f = File('${userDir.path}/cnic_back.jpg');
        await f.writeAsBytes(user.cnicBackBytes!, flush: true);
        cnicBackPath = f.path;
      }

      String? avatarPath = user.avatarFilePath;
      if (user.avatarBytes != null && user.avatarBytes!.isNotEmpty) {
        final f = File('${userDir.path}/avatar.jpg');
        await f.writeAsBytes(user.avatarBytes!, flush: true);
        avatarPath = f.path;
      } else if (!user.hasCustomAvatar) {
        final f = File('${userDir.path}/avatar.jpg');
        if (f.existsSync()) {
          try {
            f.deleteSync();
          } catch (_) {}
        }
      }

      final profileToSave = user.copyWith(
        selfieFilePath: selfiePath,
        cnicFrontFilePath: cnicFrontPath,
        cnicBackFilePath: cnicBackPath,
        avatarFilePath: avatarPath,
      );

      final jsonFile = File('${userDir.path}/profile.json');
      await jsonFile.writeAsString(jsonEncode(profileToSave.toJson()),
          flush: true);
    } catch (e) {
      debugPrint('Persistence error: $e');
    }
  }

  /// Reads one user profile and its saved documents from local storage.
  Future<UserProfile?> _loadUserFromDisk(String email) async {
    if (kIsWeb || email.isEmpty) return null;
    try {
      final baseDir = await _getStorageDir();
      if (baseDir == null) return null;

      final key = _normalizeEmailKey(email);
      final userDir = Directory('${baseDir.path}/$key');
      final jsonFile = File('${userDir.path}/profile.json');
      if (!jsonFile.existsSync()) return null;

      final jsonStr = await jsonFile.readAsString();
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;
      final profile = UserProfile.fromJson(data);

      Uint8List? selfieBytes;
      if (profile.selfieFilePath != null &&
          File(profile.selfieFilePath!).existsSync()) {
        selfieBytes = await File(profile.selfieFilePath!).readAsBytes();
      }

      Uint8List? cnicFrontBytes;
      if (profile.cnicFrontFilePath != null &&
          File(profile.cnicFrontFilePath!).existsSync()) {
        cnicFrontBytes = await File(profile.cnicFrontFilePath!).readAsBytes();
      }

      Uint8List? cnicBackBytes;
      if (profile.cnicBackFilePath != null &&
          File(profile.cnicBackFilePath!).existsSync()) {
        cnicBackBytes = await File(profile.cnicBackFilePath!).readAsBytes();
      }

      Uint8List? avatarBytes;
      if (profile.avatarFilePath != null &&
          File(profile.avatarFilePath!).existsSync()) {
        avatarBytes = await File(profile.avatarFilePath!).readAsBytes();
      }

      return profile.copyWith(
        selfieBytes: selfieBytes,
        cnicFrontBytes: cnicFrontBytes,
        cnicBackBytes: cnicBackBytes,
        avatarBytes: avatarBytes,
      );
    } catch (e) {
      debugPrint('Error loading user from disk: $e');
      return null;
    }
  }

  /// Restores saved demo profiles into the in-memory user registry.
  Future<void> _loadPersistedDefaultUsers() async {
    try {
      final saved = await _loadUserFromDisk('kheroali66@gmail.com') ??
          await _loadUserFromDisk('kherool66@gmail.com');
      if (saved != null) {
        _saveRegisteredUser(saved, persist: false);
        if (profileNotifier.value.email == 'kherool66@gmail.com' ||
            profileNotifier.value.email == 'kheroali66@gmail.com') {
          profileNotifier.value = saved;
        }
      }
    } catch (_) {}
  }

  /// Adds a newly registered profile to memory and local storage.
  void _saveRegisteredUser(UserProfile user, {bool persist = true}) {
    if (user.email.isEmpty) return;
    final lower = user.email.trim().toLowerCase();
    _registeredUsers[lower] = user;

    // Cross-link canonical aliases so updating either updates both
    if (lower == 'kheroali66@gmail.com') {
      _registeredUsers['kherool66@gmail.com'] =
          user.copyWith(email: 'kherool66@gmail.com');
    } else if (lower == 'kherool66@gmail.com') {
      _registeredUsers['kheroali66@gmail.com'] =
          user.copyWith(email: 'kheroali66@gmail.com');
    }

    if (persist) {
      _persistUser(user);
    }
  }

  /// Find a registered user by email address from in-memory cache
  UserProfile? findUser(String email) {
    return _registeredUsers[email.trim().toLowerCase()];
  }

  /// Find user from in-memory cache or asynchronously load from disk
  Future<UserProfile?> findOrLoadUser(String email) async {
    final lower = email.trim().toLowerCase();
    if (_registeredUsers.containsKey(lower)) {
      return _registeredUsers[lower];
    }
    final loaded = await _loadUserFromDisk(lower);
    if (loaded != null) {
      _saveRegisteredUser(loaded, persist: false);
      return loaded;
    }
    return null;
  }

  /// Sets the active user profile and updates registry and disk cache
  void setActiveUser(UserProfile user) {
    profileNotifier.value = user;
    _saveRegisteredUser(user);
  }

  /// Explicitly marks KYC as completed for the active user and saves state permanently
  void markKycCompleted() {
    final current = profileNotifier.value;
    final updated = current.copyWith(
      hasCompletedKyc: true,
      kycStatus: KycReviewStatus.pendingReview,
      updatedAt: DateTime.now(),
    );
    profileNotifier.value = updated;
    _saveRegisteredUser(updated);
  }

  /// Checks whether any registered user has already signed in or verified with this CNIC.
  /// If [excludeEmail] is provided, ignores that user's own profile.
  bool isCnicAlreadyRegistered(String rawCnic, {String? excludeEmail}) {
    final cleanDigits = rawCnic.replaceAll(RegExp(r'\D'), '');
    if (cleanDigits.length != 13) return false;

    final normalizedExclude = excludeEmail?.trim().toLowerCase();
    final isDemoAccount = normalizedExclude == 'kherool66@gmail.com' ||
        normalizedExclude == 'kheroali66@gmail.com' ||
        normalizedExclude == 'admin@paidix.com';

    // Check against all registered users
    for (final entry in _registeredUsers.entries) {
      final entryEmail = entry.key.toLowerCase();
      if (normalizedExclude != null) {
        if (entryEmail == normalizedExclude) continue;
        if (isDemoAccount &&
            (entryEmail == 'kherool66@gmail.com' ||
                entryEmail == 'kheroali66@gmail.com' ||
                entryEmail == 'admin@paidix.com')) {
          continue;
        }
      }
      final existingClean =
          entry.value.cnicNumber.replaceAll(RegExp(r'\D'), '');
      if (existingClean == cleanDigits) {
        return true;
      }
    }
    return false;
  }

  /// Finds an existing user profile registered with this CNIC.
  UserProfile? findUserByCnic(String rawCnic) {
    final cleanDigits = rawCnic.replaceAll(RegExp(r'\D'), '');
    if (cleanDigits.length != 13) return null;
    for (final user in _registeredUsers.values) {
      if (user.cnicNumber.replaceAll(RegExp(r'\D'), '') == cleanDigits) {
        return user;
      }
    }
    return null;
  }

  /// Synchronize details entered during the initial Sign-Up step
  void syncFromSignUp({
    required String fullName,
    required String email,
    String? countryCode,
    String? phoneNumber,
    bool smsConsent = true,
  }) {
    final current = profileNotifier.value;
    final effectiveCountryCode = countryCode ?? '+92';
    final newProfile = current.copyWith(
      fullName: fullName.trim(),
      email: email.trim(),
      countryCode: effectiveCountryCode,
      phoneNumber: (phoneNumber != null && phoneNumber.trim().isNotEmpty)
          ? phoneNumber.trim()
          : '',
      smsConsent: smsConsent,
      // For a brand new user, KYC is not completed yet
      hasCompletedKyc: false,
      kycStatus: KycReviewStatus.notStarted,
      cnicNumber: '',
      city: '',
      address: '',
      selfieBytes: null,
      selfieFilePath: null,
      cnicFrontBytes: null,
      cnicFrontFilePath: null,
      cnicBackBytes: null,
      cnicBackFilePath: null,
      clearAvatar: true,
      updatedAt: DateTime.now(),
    );
    profileNotifier.value = newProfile;
    _saveRegisteredUser(newProfile);
    activeKycStep = KycStep.personal;
  }

  /// Synchronize all steps captured during regulatory KYC onboarding
  void syncFromKyc(KycState kycState) {
    final current = profileNotifier.value;

    final p = kycState.personal;
    final id = kycState.identity;
    final photo = kycState.photo;
    final bank = kycState.bank;

    // Determine clean phone representation
    final country =
        p.countryCode.trim().isNotEmpty ? p.countryCode : current.countryCode;
    final rawPhone = p.phoneNumber.trim();
    final combinedPhone = rawPhone.isNotEmpty
        ? (rawPhone.startsWith('+') ? rawPhone : '$country$rawPhone')
        : current.phoneNumber;

    final isSubmitted = kycState.isSubmitted;

    final updated = current.copyWith(
      fullName:
          p.fullName.trim().isNotEmpty ? p.fullName.trim() : current.fullName,
      countryCode: country,
      phoneNumber: combinedPhone,
      smsConsent: p.smsConsent,
      address: (p.address != null && p.address!.trim().isNotEmpty)
          ? p.address!.trim()
          : current.address,
      city: (p.city != null && p.city!.trim().isNotEmpty)
          ? p.city!.trim()
          : current.city,
      cnicNumber: id.cnicNumber.trim().isNotEmpty
          ? id.cnicNumber.trim()
          : current.cnicNumber,
      // Front and Back CNIC bytes/paths (prefer enhanced bytes if present)
      cnicFrontBytes:
          id.enhancedFrontBytes ?? id.frontBytes ?? current.cnicFrontBytes,
      cnicFrontFilePath: id.frontFilePath ?? current.cnicFrontFilePath,
      cnicBackBytes:
          id.enhancedBackBytes ?? id.backBytes ?? current.cnicBackBytes,
      cnicBackFilePath: id.backFilePath ?? current.cnicBackFilePath,
      // Selfie bytes/paths
      selfieBytes: photo.enhancedBytes ?? photo.bytes ?? current.selfieBytes,
      selfieFilePath: photo.filePath ?? current.selfieFilePath,
      // Bank details
      bankName: bank.bankName.isNotEmpty ? bank.bankName : current.bankName,
      bankAccountNumber: bank.accountNumber.isNotEmpty
          ? bank.accountNumber
          : current.bankAccountNumber,
      bankIban: bank.iban.isNotEmpty ? bank.iban : current.bankIban,
      bankBeneficiary: bank.beneficiaryTitle.isNotEmpty
          ? bank.beneficiaryTitle
          : current.bankBeneficiary,
      hasCompletedKyc: isSubmitted ? true : current.hasCompletedKyc,
      kycStatus:
          isSubmitted ? KycReviewStatus.pendingReview : current.kycStatus,
      updatedAt: DateTime.now(),
    );

    profileNotifier.value = updated;
    _saveRegisteredUser(updated);

    // If submitted with account number, save directly to user's linked bank accounts
    if (isSubmitted && bank.accountNumber.isNotEmpty) {
      try {
        final key = _normalizeEmailKey(updated.email);
        final newAccount = BankAccountItem(
          id: 'kyc_bank_${DateTime.now().millisecondsSinceEpoch}',
          bankName: bank.bankName.isNotEmpty
              ? bank.bankName
              : 'Meezan Bank Limited',
          holder: bank.beneficiaryTitle.isNotEmpty
              ? bank.beneficiaryTitle
              : updated.fullName,
          accountNumber: bank.accountNumber,
          iban: bank.iban,
          isPrimary: true,
        );
        final existing = _bankAccountsCache[key] ?? [];
        final updatedList = [
          newAccount,
          ...existing.map((a) => a.copyWith(isPrimary: false)),
        ];
        saveBankAccounts(updated.email, updatedList);
      } catch (_) {}
    }
  }

  /// Simulates server-side verification approval for the active user.
  void approveKycVerification() {
    final current = profileNotifier.value;
    final updated = current.copyWith(
      kycStatus: KycReviewStatus.verified,
      hasCompletedKyc: true,
      updatedAt: DateTime.now(),
    );
    profileNotifier.value = updated;
    _saveRegisteredUser(updated);
  }

  /// Update personal information and documents from the "Edit Profile" action
  void updateProfile({
    String? fullName,
    String? phoneNumber,
    String? cnicNumber,
    String? city,
    String? address,
    KycReviewStatus? kycStatus,
    Uint8List? selfieBytes,
    String? selfieFilePath,
    Uint8List? cnicFrontBytes,
    String? cnicFrontFilePath,
    Uint8List? cnicBackBytes,
    String? cnicBackFilePath,
    Uint8List? avatarBytes,
    String? avatarFilePath,
    bool clearAvatar = false,
  }) {
    final current = profileNotifier.value;
    final updated = current.copyWith(
      fullName: fullName != null && fullName.trim().isNotEmpty
          ? fullName.trim()
          : current.fullName,
      phoneNumber: phoneNumber != null && phoneNumber.trim().isNotEmpty
          ? phoneNumber.trim()
          : current.phoneNumber,
      cnicNumber: cnicNumber != null && cnicNumber.trim().isNotEmpty
          ? cnicNumber.trim()
          : current.cnicNumber,
      city: city != null ? city.trim() : current.city,
      address: address != null ? address.trim() : current.address,
      kycStatus: kycStatus ?? current.kycStatus,
      selfieBytes: selfieBytes ?? current.selfieBytes,
      selfieFilePath: selfieFilePath ?? current.selfieFilePath,
      cnicFrontBytes: cnicFrontBytes ?? current.cnicFrontBytes,
      cnicFrontFilePath: cnicFrontFilePath ?? current.cnicFrontFilePath,
      cnicBackBytes: cnicBackBytes ?? current.cnicBackBytes,
      cnicBackFilePath: cnicBackFilePath ?? current.cnicBackFilePath,
      avatarBytes: avatarBytes,
      avatarFilePath: avatarFilePath,
      clearAvatar: clearAvatar,
      updatedAt: DateTime.now(),
    );

    profileNotifier.value = updated;
    _saveRegisteredUser(updated);
  }

  /// Restores the display preferences and temporary balance reveal state to their defaults.
  void resetToDefault() {
    profileNotifier.value = UserProfile.defaultProfile();
    activeKycStep = KycStep.personal;
  }

  final Map<String, List<BankAccountItem>> _bankAccountsCache = {};

  /// Synchronous retrieval of bank accounts for initial UI render
  List<BankAccountItem> getBankAccountsSync(String email) {
    final key = _normalizeEmailKey(email);
    if (_bankAccountsCache.containsKey(key)) {
      return List<BankAccountItem>.from(_bankAccountsCache[key]!);
    }
    final defaultList = [
      BankAccountItem(
        id: 'default_jazzcash',
        bankName: 'JazzCash (Mobilink Microfinance Bank)',
        holder: profileNotifier.value.fullName.isNotEmpty
            ? profileNotifier.value.fullName
            : 'Abdullah Azeem',
        accountNumber: '03225352786',
        iban: '',
        isPrimary: true,
      ),
    ];
    _bankAccountsCache[key] = defaultList;
    return List<BankAccountItem>.from(defaultList);
  }

  /// Loads bank accounts for a given user email, with local disk caching
  Future<List<BankAccountItem>> loadBankAccounts(String email) async {
    final key = _normalizeEmailKey(email);
    if (_bankAccountsCache.containsKey(key)) {
      return List<BankAccountItem>.from(_bankAccountsCache[key]!);
    }

    try {
      final baseDir = await _getStorageDir();
      if (baseDir != null) {
        final userDir = Directory('${baseDir.path}/$key');
        final bankFile = File('${userDir.path}/bank_accounts.json');
        if (bankFile.existsSync()) {
          final jsonStr = await bankFile.readAsString();
          final list = jsonDecode(jsonStr) as List<dynamic>;
          final loaded = list
              .map((e) => BankAccountItem.fromJson(e as Map<String, dynamic>))
              .toList();
          if (loaded.isNotEmpty) {
            _bankAccountsCache[key] = loaded;
            return List<BankAccountItem>.from(loaded);
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading bank accounts: $e');
    }

    // Default seed account matching Screenshot 1 & 2
    final defaultList = [
      BankAccountItem(
        id: 'default_jazzcash',
        bankName: 'JazzCash (Mobilink Microfinance Bank)',
        holder: profileNotifier.value.fullName.isNotEmpty
            ? profileNotifier.value.fullName
            : 'Abdullah Azeem',
        accountNumber: '03225352786',
        iban: '',
        isPrimary: true,
      ),
    ];
    _bankAccountsCache[key] = defaultList;
    return List<BankAccountItem>.from(defaultList);
  }

  /// Saves bank accounts for a given user email to memory and disk, syncing primary details
  Future<void> saveBankAccounts(
      String email, List<BankAccountItem> accounts) async {
    final key = _normalizeEmailKey(email);
    _bankAccountsCache[key] = List<BankAccountItem>.from(accounts);

    // Sync primary bank account with active profile
    final primary = accounts.firstWhere(
      (a) => a.isPrimary,
      orElse: () => accounts.isNotEmpty
          ? accounts.first
          : const BankAccountItem(
              id: '',
              bankName: '',
              holder: '',
              accountNumber: '',
            ),
    );

    if (primary.bankName.isNotEmpty) {
      final current = profileNotifier.value;
      final updated = current.copyWith(
        bankName: primary.bankName,
        bankBeneficiary: primary.holder,
        bankIban: primary.iban.isNotEmpty ? primary.iban : primary.accountNumber,
        updatedAt: DateTime.now(),
      );
      profileNotifier.value = updated;
      _saveRegisteredUser(updated);
    }

    try {
      final baseDir = await _getStorageDir();
      if (baseDir != null) {
        final userDir = Directory('${baseDir.path}/$key');
        if (!userDir.existsSync()) {
          userDir.createSync(recursive: true);
        }
        final bankFile = File('${userDir.path}/bank_accounts.json');
        final jsonStr =
            jsonEncode(accounts.map((a) => a.toJson()).toList());
        await bankFile.writeAsString(jsonStr, flush: true);
      }
    } catch (e) {
      debugPrint('Error saving bank accounts: $e');
    }
  }
}
