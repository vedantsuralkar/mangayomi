// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'myanimelist.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$myAnimeListHash() => r'd69a03e6f385688047c13771528c086542e03218';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

abstract class _$MyAnimeList extends BuildlessAutoDisposeNotifier<void> {
  late final int syncId;
  late final bool? isManga;

  void build({
    required int syncId,
    required bool? isManga,
  });
}

/// See also [MyAnimeList].
@ProviderFor(MyAnimeList)
const myAnimeListProvider = MyAnimeListFamily();

/// See also [MyAnimeList].
class MyAnimeListFamily extends Family<void> {
  /// See also [MyAnimeList].
  const MyAnimeListFamily();

  /// See also [MyAnimeList].
  MyAnimeListProvider call({
    required int syncId,
    required bool? isManga,
  }) {
    return MyAnimeListProvider(
      syncId: syncId,
      isManga: isManga,
    );
  }

  @override
  MyAnimeListProvider getProviderOverride(
    covariant MyAnimeListProvider provider,
  ) {
    return call(
      syncId: provider.syncId,
      isManga: provider.isManga,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'myAnimeListProvider';
}

/// See also [MyAnimeList].
class MyAnimeListProvider
    extends AutoDisposeNotifierProviderImpl<MyAnimeList, void> {
  /// See also [MyAnimeList].
  MyAnimeListProvider({
    required int syncId,
    required bool? isManga,
  }) : this._internal(
          () => MyAnimeList()
            ..syncId = syncId
            ..isManga = isManga,
          from: myAnimeListProvider,
          name: r'myAnimeListProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$myAnimeListHash,
          dependencies: MyAnimeListFamily._dependencies,
          allTransitiveDependencies:
              MyAnimeListFamily._allTransitiveDependencies,
          syncId: syncId,
          isManga: isManga,
        );

  MyAnimeListProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.syncId,
    required this.isManga,
  }) : super.internal();

  final int syncId;
  final bool? isManga;

  @override
  void runNotifierBuild(
    covariant MyAnimeList notifier,
  ) {
    return notifier.build(
      syncId: syncId,
      isManga: isManga,
    );
  }

  @override
  Override overrideWith(MyAnimeList Function() create) {
    return ProviderOverride(
      origin: this,
      override: MyAnimeListProvider._internal(
        () => create()
          ..syncId = syncId
          ..isManga = isManga,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        syncId: syncId,
        isManga: isManga,
      ),
    );
  }

  @override
  AutoDisposeNotifierProviderElement<MyAnimeList, void> createElement() {
    return _MyAnimeListProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is MyAnimeListProvider &&
        other.syncId == syncId &&
        other.isManga == isManga;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, syncId.hashCode);
    hash = _SystemHash.combine(hash, isManga.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin MyAnimeListRef on AutoDisposeNotifierProviderRef<void> {
  /// The parameter `syncId` of this provider.
  int get syncId;

  /// The parameter `isManga` of this provider.
  bool? get isManga;
}

class _MyAnimeListProviderElement
    extends AutoDisposeNotifierProviderElement<MyAnimeList, void>
    with MyAnimeListRef {
  _MyAnimeListProviderElement(super.provider);

  @override
  int get syncId => (origin as MyAnimeListProvider).syncId;
  @override
  bool? get isManga => (origin as MyAnimeListProvider).isManga;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
