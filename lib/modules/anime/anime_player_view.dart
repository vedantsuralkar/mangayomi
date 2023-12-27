import 'dart:async';
import 'dart:io';
import 'package:draggable_menu/draggable_menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' as riv;
import 'package:mangayomi/models/chapter.dart';
import 'package:mangayomi/models/video.dart' as vid;
import 'package:mangayomi/modules/anime/providers/anime_player_controller_provider.dart';
import 'package:mangayomi/modules/anime/widgets/custom_seekbar.dart';
import 'package:mangayomi/modules/anime/widgets/indicator_builder.dart';
import 'package:mangayomi/modules/manga/reader/providers/push_router.dart';
import 'package:mangayomi/modules/more/settings/player/providers/player_state_provider.dart';
import 'package:mangayomi/modules/widgets/progress_center.dart';
import 'package:mangayomi/providers/l10n_providers.dart';
import 'package:mangayomi/services/get_video_list.dart';
import 'package:mangayomi/utils/colors.dart';
import 'package:mangayomi/utils/media_query.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:media_kit_video/media_kit_video_controls/src/controls/extensions/duration.dart';
import 'package:screen_brightness/screen_brightness.dart';

class AnimePlayerView extends riv.ConsumerStatefulWidget {
  final Chapter episode;
  const AnimePlayerView({super.key, required this.episode});

  @override
  riv.ConsumerState<AnimePlayerView> createState() => _AnimePlayerViewState();
}

class _AnimePlayerViewState extends riv.ConsumerState<AnimePlayerView> {
  @override
  Widget build(BuildContext context) {
    final serversData = ref.watch(getVideoListProvider(
      episode: widget.episode,
    ));
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
    return serversData.when(
      data: (data) {
        if (data.$1.isEmpty &&
            !(widget.episode.manga.value!.isLocalArchive ?? false)) {
          return Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            appBar: AppBar(
              title: const Text(''),
              leading: BackButton(
                onPressed: () {
                  SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
                      overlays: SystemUiOverlay.values);
                  Navigator.pop(context);
                },
              ),
            ),
            body: WillPopScope(
              onWillPop: () async {
                SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
                    overlays: SystemUiOverlay.values);
                Navigator.pop(context);
                return false;
              },
              child: const Center(
                child: Text("Error"),
              ),
            ),
          );
        }

        return AnimeStreamPage(
          episode: widget.episode,
          videos: data.$1,
          isLocal: data.$2,
        );
      },
      error: (error, stackTrace) => Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: const Text(''),
          leading: BackButton(
            onPressed: () {
              SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
                  overlays: SystemUiOverlay.values);
              Navigator.pop(context);
            },
          ),
        ),
        body: WillPopScope(
          onWillPop: () async {
            SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
                overlays: SystemUiOverlay.values);

            Navigator.pop(context);
            return false;
          },
          child: Center(
            child: Text(error.toString()),
          ),
        ),
      ),
      loading: () {
        return Scaffold(
          backgroundColor: Colors.black,
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            title: const Text(''),
            leading: BackButton(
              color: Colors.white,
              onPressed: () {
                SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
                    overlays: SystemUiOverlay.values);
                Navigator.pop(context);
              },
            ),
          ),
          body: WillPopScope(
            onWillPop: () async {
              SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
                  overlays: SystemUiOverlay.values);

              Navigator.pop(context);
              return false;
            },
            child: const ProgressCenter(),
          ),
        );
      },
    );
  }
}

class AnimeStreamPage extends riv.ConsumerStatefulWidget {
  final List<vid.Video> videos;
  final Chapter episode;
  final bool isLocal;
  const AnimeStreamPage(
      {super.key,
      required this.isLocal,
      required this.videos,
      required this.episode});

  @override
  riv.ConsumerState<AnimeStreamPage> createState() => _AnimeStreamPageState();
}

class _AnimeStreamPageState extends riv.ConsumerState<AnimeStreamPage> {
  late final GlobalKey<VideoState> _key = GlobalKey<VideoState>();
  late final Player _player = Player();
  late final VideoController _controller = VideoController(_player);
  late final _streamController =
      ref.read(animeStreamControllerProvider(episode: widget.episode).notifier);
  late final _firstVid = widget.videos.first;

  late final ValueNotifier<VideoPrefs?> _video = ValueNotifier(VideoPrefs(
      videoTrack: VideoTrack(
          _firstVid.originalUrl, _firstVid.quality, _firstVid.quality),
      headers: _firstVid.headers));

  late final ValueNotifier<SubtitleTrack?> _subtitle = ValueNotifier(
      SubtitleTrack.uri(_firstVid.subtitles?.first.file ?? "",
          title: _firstVid.subtitles?.first.label,
          language: _firstVid.subtitles?.first.label));

  late final ValueNotifier<AudioTrack?> _audio = ValueNotifier(AudioTrack.uri(
      _firstVid.audios?.first.file ?? "",
      title: _firstVid.audios?.first.label,
      language: _firstVid.audios?.first.label));

  final ValueNotifier<double> _playbackSpeed = ValueNotifier(1.0);
  bool _seekToCurrentPosition = true;
  bool _initSubtitle = true;
  final ValueNotifier<bool> _enterFullScreen = ValueNotifier(false);
  late final ValueNotifier<Duration> _currentPosition =
      ValueNotifier(_streamController.geTCurrentPosition());
  final ValueNotifier<Duration?> _currentTotalDuration = ValueNotifier(null);
  final ValueNotifier<bool> _showFitLabel = ValueNotifier(false);
  final ValueNotifier<bool> _isCompleted = ValueNotifier(false);
  final ValueNotifier<Duration?> _tempPosition = ValueNotifier(null);
  final ValueNotifier<BoxFit> _fit = ValueNotifier(BoxFit.contain);

  final bool _isDesktop =
      Platform.isWindows || Platform.isMacOS || Platform.isLinux;

  late StreamSubscription<Duration> _currentPositionSub =
      _player.stream.position.listen(
    (position) async {
      if (_seekToCurrentPosition && _currentPosition.value != Duration.zero) {
        await _player.stream.buffer.first;
        _player.seek(_currentPosition.value);
        _isCompleted.value = _player.state.duration.inSeconds -
                _currentPosition.value.inSeconds <=
            10;
        _seekToCurrentPosition = false;
      } else {
        _currentPosition.value = position;
      }
      if ((_firstVid.subtitles ?? []).isNotEmpty) {
        if (_initSubtitle) {
          try {
            _player.setSubtitleTrack(_subtitle.value ?? SubtitleTrack.no());
          } catch (_) {}
          _initSubtitle = false;
        }
      }
    },
  );

  late final StreamSubscription<Duration> _currentTotalDurationSub =
      _player.stream.duration.listen(
    (duration) {
      _currentTotalDuration.value = duration;
    },
  );
  double _brightnessValue = 0.0;
  @override
  void initState() {
    _setCurrentPosition(true);
    _currentPositionSub;
    _currentTotalDurationSub;
    _player.open(Media(_video.value!.videoTrack!.id,
        httpHeaders: _video.value!.headers));
    _setPlaybackSpeed(ref.read(defaultPlayBackSpeedStateProvider));
    Future.microtask(() async {
      try {
        _brightnessValue = await ScreenBrightness().current;
        ScreenBrightness().onCurrentBrightnessChanged.listen((value) {
          if (mounted) {
            setState(() {
              _brightnessValue = value;
            });
          }
        });
      } catch (_) {}
    });
    super.initState();
  }

  @override
  void dispose() {
    _setCurrentPosition(true);
    _player.dispose();
    _currentPositionSub.cancel();
    _currentTotalDurationSub.cancel();
    _setFullscreen(false);
    super.dispose();
  }

  void _setCurrentPosition(bool save) {
    _streamController.setCurrentPosition(
        _currentPosition.value, _currentTotalDuration.value,
        save: save);
    _streamController.setAnimeHistoryUpdate();
  }

  void _setFullscreen(bool state) {
    if (state) {
      SystemChrome.setPreferredOrientations(
          [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight
      ]);
    }
  }

  Widget _videoQualityWidget(BuildContext context) {
    List<VideoPrefs> videoQuality = _player.state.tracks.video
        .where((element) =>
            element.w != null && element.h != null && widget.isLocal)
        .toList()
        .map((e) => VideoPrefs(videoTrack: e, isLocal: true))
        .toList();

    if (widget.videos.isNotEmpty && !widget.isLocal) {
      for (var video in widget.videos) {
        videoQuality.add(VideoPrefs(
            videoTrack: VideoTrack(video.url, video.quality, video.quality),
            headers: video.headers,
            isLocal: false));
      }
    }

    return Column(
      children: videoQuality.map((quality) {
        final selected =
            _video.value!.videoTrack!.title == quality.videoTrack!.title ||
                widget.isLocal;
        return GestureDetector(
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Icon(
                  Icons.check,
                  color: selected ? Colors.white : Colors.transparent,
                ),
              ),
              Expanded(
                child: Text(
                  widget.isLocal
                      ? _firstVid.quality
                      : quality.videoTrack!.title!,
                  style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                      fontSize: 16,
                      color: selected
                          ? Colors.white
                          : Colors.white.withOpacity(0.6)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          onTap: () {
            _video.value = quality; // change the video quality
            if (quality.isLocal) {
              if (widget.isLocal) {
                _player.setVideoTrack(quality.videoTrack!);
              } else {
                _player.open(Media(quality.videoTrack!.id,
                    httpHeaders: quality.headers));
              }
            } else {
              _player.open(
                  Media(quality.videoTrack!.id, httpHeaders: quality.headers));
            }
            _seekToCurrentPosition = true;
            _currentPositionSub = _player.stream.position.listen(
              (position) async {
                if (_seekToCurrentPosition &&
                    _currentPosition.value != Duration.zero) {
                  await _player.stream.buffer.first;
                  _player.seek(_currentPosition.value);
                  try {
                    _player.setSubtitleTrack(_subtitle.value!);
                  } catch (_) {}

                  _seekToCurrentPosition = false;
                } else {
                  _currentPosition.value = position;
                }
              },
            );
            Navigator.pop(context);
          },
        );
      }).toList(),
    );
  }

  void _videoSettingDraggableMenu(BuildContext context) async {
    final l10n = l10nLocalizations(context)!;
    _player.pause();
    await DraggableMenu.open(
        context,
        DraggableMenu(
          ui: ClassicDraggableMenu(
              radius: 30,
              barItem: Container(),
              color: Colors.black.withOpacity(0.6)),
          minimizeThreshold: 0.6,
          levels: [
            DraggableMenuLevel.ratio(ratio: 2 / 3),
            DraggableMenuLevel.ratio(ratio: 0.9),
          ],
          minimizeBeforeFastDrag: true,
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            clipBehavior: Clip.antiAliasWithSaveLayer,
            child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(
                                  top: 8, left: 12, bottom: 5),
                              child: Row(
                                children: [
                                  Text(l10n.video_quality,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyLarge!
                                          .copyWith(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 20)),
                                ],
                              ),
                            ),
                            const Padding(
                                padding: EdgeInsets.symmetric(vertical: 5)),
                            _videoQualityWidget(context)
                          ],
                        ),
                      ),
                    ),
                    Container(
                        color: Colors.white,
                        width: 0.2,
                        height: mediaHeight(context, 1)),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(
                                  top: 8, left: 12, bottom: 5),
                              child: Row(
                                children: [
                                  Text(
                                    l10n.video_subtitle,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyLarge!
                                        .copyWith(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 20),
                                  ),
                                ],
                              ),
                            ),
                            const Padding(
                                padding: EdgeInsets.symmetric(vertical: 5)),
                            _videoSubtitle(context)
                          ],
                        ),
                      ),
                    ),
                    Container(
                        color: Colors.white,
                        width: 0.2,
                        height: mediaHeight(context, 1)),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(
                                  top: 8, left: 12, bottom: 5),
                              child: Row(
                                children: [
                                  Text(
                                    l10n.video_audio,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyLarge!
                                        .copyWith(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 20),
                                  ),
                                ],
                              ),
                            ),
                            const Padding(
                                padding: EdgeInsets.symmetric(vertical: 5)),
                            _videoAudios(context)
                          ],
                        ),
                      ),
                    )
                  ],
                )),
          ),
        ));
    _player.play();
  }

  Widget _videoSubtitle(BuildContext context) {
    List<VideoPrefs> videoSubtitle = _player.state.tracks.subtitle
        .toList()
        .map((e) => VideoPrefs(isLocal: true, subtitle: e))
        .toList();
    SubtitleTrack? subtitle;

    List<String> subs = [];
    if (widget.videos.isNotEmpty && !widget.isLocal) {
      for (var video in widget.videos) {
        for (var sub in video.subtitles ?? []) {
          if (!subs.contains(sub.file)) {
            videoSubtitle.add(VideoPrefs(
                isLocal: false,
                subtitle: SubtitleTrack.uri(sub.file!,
                    title: sub.label, language: sub.label)));
            subs.add(sub.file!);
          }
        }
      }
    }
    if (widget.isLocal) {
      subtitle = _player.state.track.subtitle;
    } else {
      try {
        subtitle = _subtitle.value;
      } catch (_) {}
    }
    videoSubtitle = videoSubtitle
        .map((e) {
          VideoPrefs vid = e;
          vid.title = vid.subtitle?.title ??
              vid.subtitle?.language ??
              vid.subtitle?.channels ??
              "";
          return vid;
        })
        .toList()
        .where((element) => element.title!.isNotEmpty)
        .toList();
    videoSubtitle.sort((a, b) => a.title!.compareTo(b.title!));
    videoSubtitle.insert(
        0, VideoPrefs(isLocal: false, subtitle: SubtitleTrack.no()));
    return Column(
      children: videoSubtitle.toSet().toList().map((sub) {
        final selected = subtitle != null && sub.subtitle == subtitle;
        return GestureDetector(
          onTap: () {
            Navigator.pop(context);
            try {
              _player.setSubtitleTrack(sub.subtitle!);
              if (!widget.isLocal) _subtitle.value = sub.subtitle;
            } catch (_) {}
          },
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Icon(
                  Icons.check,
                  color: selected ? Colors.white : Colors.transparent,
                ),
              ),
              Expanded(
                child: Text(
                  sub.title ??
                      sub.subtitle?.title ??
                      sub.subtitle?.language ??
                      sub.subtitle?.channels ??
                      "None",
                  style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                      fontSize: 16,
                      color: selected
                          ? Colors.white
                          : Colors.white.withOpacity(0.6)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _videoAudios(BuildContext context) {
    List<VideoPrefs> videoAudio = _player.state.tracks.audio
        .toList()
        .map((e) => VideoPrefs(isLocal: true, audio: e))
        .toList();
    AudioTrack? audio;

    List<String> audios = [];
    if (widget.videos.isNotEmpty && !widget.isLocal) {
      for (var video in widget.videos) {
        for (var audio in video.audios ?? []) {
          if (!audios.contains(audio.file)) {
            videoAudio.add(VideoPrefs(
                isLocal: false,
                audio: AudioTrack.uri(audio.file!,
                    title: audio.label, language: audio.label)));
            audios.add(audio.file!);
          }
        }
      }
    }
    if (widget.isLocal) {
      audio = _player.state.track.audio;
    } else {
      try {
        audio = _audio.value;
      } catch (_) {}
    }
    videoAudio = videoAudio
        .map((e) {
          VideoPrefs vid = e;
          vid.title = vid.audio?.title ??
              vid.audio?.language ??
              vid.audio?.channels ??
              "";
          return vid;
        })
        .toList()
        .where((element) => element.title!.isNotEmpty)
        .toList();
    videoAudio.sort((a, b) => a.title!.compareTo(b.title!));
    videoAudio.insert(
        0, VideoPrefs(isLocal: false, subtitle: SubtitleTrack.no()));
    return Column(
      children: videoAudio.toSet().toList().map((aud) {
        final selected = audio != null && aud.audio == audio;
        return GestureDetector(
          onTap: () {
            Navigator.pop(context);
            try {
              _player.setAudioTrack(aud.audio!);
              if (!widget.isLocal) _audio.value = aud.audio;
            } catch (_) {}
          },
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Icon(
                  Icons.check,
                  color: selected ? Colors.white : Colors.transparent,
                ),
              ),
              Expanded(
                child: Text(
                  aud.title ??
                      aud.audio?.title ??
                      aud.audio?.language ??
                      aud.audio?.channels ??
                      "None",
                  style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                      fontSize: 16,
                      color: selected
                          ? Colors.white
                          : Colors.white.withOpacity(0.6)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Future<void> _setPlaybackSpeed(double speed) async {
    await _player.setRate(speed);
    _playbackSpeed.value = speed;
  }

  void _togglePlaybackSpeed() {
    List<double> allowedSpeeds = [0.25, 0.5, 0.75, 1.0, 1.25, 1.50, 1.75, 2.0];
    if (allowedSpeeds.indexOf(_playbackSpeed.value) <
        allowedSpeeds.length - 1) {
      _setPlaybackSpeed(
          allowedSpeeds[allowedSpeeds.indexOf(_playbackSpeed.value) + 1]);
    } else {
      _setPlaybackSpeed(allowedSpeeds[0]);
    }
  }

  Future<void> _changeFitLabel(WidgetRef ref) async {
    List<BoxFit> fitList = [
      BoxFit.contain,
      BoxFit.cover,
      BoxFit.fill,
      BoxFit.fitHeight,
      BoxFit.fitWidth,
      BoxFit.none
    ];
    _showFitLabel.value = true;
    BoxFit? fit;
    if (fitList.indexOf(_fit.value) < fitList.length - 1) {
      fit = fitList[fitList.indexOf(_fit.value) + 1];
    } else {
      fit = fitList[0];
    }
    _fit.value = fit;
    _key.currentState?.update(fit: fit);
    await Future.delayed(const Duration(seconds: 2));
    _showFitLabel.value = false;
  }

  Widget _seekToWidget() {
    final defaultSkipIntroLength =
        ref.watch(defaultSkipIntroLengthStateProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: SizedBox(
        height: 35,
        child: ElevatedButton(
            onPressed: () async {
              _tempPosition.value = Duration(
                  seconds: defaultSkipIntroLength +
                      _currentPosition.value.inSeconds -
                      _currentPosition.value.inSeconds);
              await _player.seek(Duration(
                  seconds: _currentPosition.value.inSeconds +
                      defaultSkipIntroLength));
              _tempPosition.value = null;
            },
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text("+$defaultSkipIntroLength",
                  style: const TextStyle(fontWeight: FontWeight.w100)),
            )),
      ),
    );
  }

  List<Widget> _mobileBottomButtonBar(BuildContext context, bool isFullScreen) {
    return [
      Flexible(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _seekToWidget(),
                  Row(
                    children: [
                      if (!isFullScreen)
                        IconButton(
                          padding: const EdgeInsets.all(5),
                          onPressed: () => _videoSettingDraggableMenu(context),
                          icon: const Icon(
                            Icons.video_settings,
                            color: Colors.white,
                          ),
                        ),
                      TextButton(
                          child: ValueListenableBuilder<double>(
                            valueListenable: _playbackSpeed,
                            builder: (context, value, child) {
                              return Text(
                                "${value}x",
                                style: const TextStyle(color: Colors.white),
                              );
                            },
                          ),
                          onPressed: () {
                            _togglePlaybackSpeed();
                          }),
                      IconButton(
                        icon: const Icon(Icons.fit_screen_outlined,
                            color: Colors.white),
                        onPressed: () async {
                          _changeFitLabel(ref);
                        },
                      ),
                      ValueListenableBuilder<bool>(
                          valueListenable: _enterFullScreen,
                          builder: (context, snapshot, _) {
                            return IconButton(
                              onPressed: () {
                                _setFullscreen(!snapshot);
                                _enterFullScreen.value = !snapshot;
                              },
                              icon: Icon(snapshot
                                  ? Icons.fullscreen_exit
                                  : Icons.fullscreen),
                              iconSize: 25,
                              color: Colors.white,
                            );
                          })
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: CustomSeekBar(
                player: _controller.player,
                onSeekStart: (start) {
                  _tempPosition.value = start;
                },
                onSeekEnd: (end) {
                  _tempPosition.value = null;
                },
              ),
            ),
          ],
        ),
      )
    ];
  }

  List<Widget> _desktopBottomButtonBar(
      BuildContext context, bool isFullScreen) {
    bool hasPrevEpisode = _streamController.getEpisodeIndex().$1 + 1 !=
        _streamController
            .getEpisodesLength(_streamController.getEpisodeIndex().$2);
    bool hasNextEpisode = _streamController.getEpisodeIndex().$1 != 0;
    return [
      Flexible(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: Row(
                children: [
                  _seekToWidget(),
                ],
              ),
            ),
            SizedBox(
                height: 20,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: CustomSeekBar(
                    player: _controller.player,
                    onSeekStart: (start) {
                      _tempPosition.value = start;
                    },
                    onSeekEnd: (end) {
                      _tempPosition.value = null;
                    },
                  ),
                )),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    if (hasPrevEpisode)
                      IconButton(
                        onPressed: () {
                          if (isFullScreen) {
                            _key.currentState?.exitFullscreen();
                          }
                          pushReplacementMangaReaderView(
                              context: context,
                              chapter: _streamController.getPrevEpisode());
                        },
                        icon: const Icon(
                          Icons.skip_previous,
                          color: Colors.white,
                        ),
                      ),
                    const MaterialDesktopPlayOrPauseButton(iconSize: 25),
                    if (hasNextEpisode)
                      IconButton(
                        onPressed: () {
                          if (isFullScreen) {
                            _key.currentState?.exitFullscreen();
                          }
                          pushReplacementMangaReaderView(
                            context: context,
                            chapter: _streamController.getNextEpisode(),
                          );
                        },
                        icon: const Icon(Icons.skip_next, color: Colors.white),
                      ),
                    const MaterialDesktopVolumeButton(iconSize: 25),
                    const MaterialDesktopPositionIndicator()
                  ],
                ),
                Row(
                  children: [
                    if (!isFullScreen)
                      IconButton(
                        onPressed: () => _videoSettingDraggableMenu(context),
                        icon: const Icon(
                          Icons.video_settings,
                          color: Colors.white,
                        ),
                      ),
                    TextButton(
                        child: ValueListenableBuilder<double>(
                          valueListenable: _playbackSpeed,
                          builder: (context, value, child) {
                            return Text(
                              "${value}x",
                              style: const TextStyle(color: Colors.white),
                            );
                          },
                        ),
                        onPressed: () {
                          _togglePlaybackSpeed();
                        }),
                    IconButton(
                      icon: const Icon(Icons.fit_screen_outlined,
                          color: Colors.white),
                      onPressed: () async {
                        _changeFitLabel(ref);
                      },
                    ),
                    const MaterialDesktopFullscreenButton()
                  ],
                ),
              ],
            ),
          ],
        ),
      )
    ];
  }

  List<Widget> _topButtonBar(BuildContext context, bool isFullScreen) {
    return [
      Flexible(
        child: Row(
          children: [
            if (isFullScreen && (Platform.isIOS || Platform.isAndroid)) ...[
              MaterialFullscreenButton(
                icon: Icon(Platform.isIOS || Platform.isMacOS
                    ? Icons.arrow_back_ios
                    : Icons.arrow_back),
              )
            ] else ...[
              if (isFullScreen)
                MaterialDesktopFullscreenButton(
                    icon: Icon(Platform.isMacOS
                        ? Icons.arrow_back_ios
                        : Icons.arrow_back))
            ],
            if (!isFullScreen)
              BackButton(
                color: Colors.white,
                onPressed: () {
                  SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
                      overlays: SystemUiOverlay.values);
                  Navigator.pop(context);
                },
              ),
            Flexible(
              child: ListTile(
                dense: true,
                title: SizedBox(
                  width: mediaWidth(context, 0.8),
                  child: Text(
                    widget.episode.manga.value!.name!,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.white),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                subtitle: SizedBox(
                  width: mediaWidth(context, 0.8),
                  child: Text(
                    widget.episode.name!,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: Colors.white.withOpacity(0.7)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ];
  }

  void _resize(BoxFit fit) async {
    await Future.delayed(const Duration(milliseconds: 100));
    if (mounted) {
      _key.currentState?.update(
          fit: fit,
          width: mediaWidth(context, 1),
          height: mediaHeight(context, 1));
    }
  }

  Widget _videoPlayer(BuildContext context) {
    final fit = _fit.value;
    _resize(fit);
    return Stack(
      children: [
        Video(
          subtitleViewConfiguration: const SubtitleViewConfiguration(
            style: TextStyle(
                fontSize: 50,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontFamily: "",
                shadows: [Shadow(offset: Offset(0.2, 0.0), blurRadius: 7.0)],
                backgroundColor: Colors.transparent),
          ),
          fit: fit,
          key: _key,
          controller: _controller,
          width: mediaWidth(context, 1),
          height: mediaHeight(context, 1),
          resumeUponEnteringForegroundMode: true,
        ),
        ValueListenableBuilder(
            valueListenable: _showFitLabel,
            builder: (context, showFitLabel, child) => showFitLabel
                ? ValueListenableBuilder(
                    valueListenable: _fit,
                    builder: (context, fit, child) => Positioned.fill(
                      child: Positioned.fill(
                          child: Center(
                              child: Text(
                        fit.name.toUpperCase(),
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 40.0),
                      ))),
                    ),
                  )
                : Container()),
      ],
    );
  }

  Widget _mobilePlayer() {
    MaterialVideoControlsThemeData materialVideoControlsThemeData(
            bool isFullScreen) =>
        MaterialVideoControlsThemeData(
            visibleOnMount: true,
            buttonBarHeight: 100,
            seekOnDoubleTap: true,
            seekGesture: true,
            horizontalGestureSensitivity: 5000,
            verticalGestureSensitivity: 500,
            controlsHoverDuration: const Duration(seconds: 15),
            volumeGesture: true,
            brightnessGesture: true,
            seekBarThumbSize: 15,
            seekBarHeight: 5,
            displaySeekBar: false,
            volumeIndicatorBuilder: (_, value) =>
                MediaIndicatorBuilder(value: value, isVolumeIndicator: true),
            brightnessIndicatorBuilder: (_, value) => MediaIndicatorBuilder(
                value: _brightnessValue, isVolumeIndicator: false),
            seekIndicatorBuilder: (context, duration) {
              return _seekIndicatorTextWidget(duration, _currentPosition.value);
            },
            seekBarPositionColor: primaryColor(context),
            seekBarThumbColor: primaryColor(context),
            primaryButtonBar: [
              ValueListenableBuilder<Duration?>(
                  valueListenable: _tempPosition,
                  builder: (context, snapshot, _) {
                    return snapshot != null
                        ? _seekIndicatorTextWidget(
                            snapshot, _currentPosition.value)
                        : Expanded(
                            child: Row(
                              children: _mobilePrimaryButtonBar(isFullScreen),
                            ),
                          );
                  })
            ],
            topButtonBarMargin: const EdgeInsets.all(0),
            topButtonBar: _topButtonBar(context, isFullScreen),
            bottomButtonBarMargin: const EdgeInsets.only(left: 8, right: 8),
            bottomButtonBar: _mobileBottomButtonBar(context, isFullScreen));
    return MaterialVideoControlsTheme(
        normal: materialVideoControlsThemeData(false),
        fullscreen: materialVideoControlsThemeData(true),
        child: _videoPlayer(context));
  }

  List<Widget> _mobilePrimaryButtonBar(bool isFullScreen) {
    bool hasPrevEpisode = _streamController.getEpisodeIndex().$1 + 1 !=
        _streamController
            .getEpisodesLength(_streamController.getEpisodeIndex().$2);
    bool hasNextEpisode = _streamController.getEpisodeIndex().$1 != 0;
    return [
      const Spacer(flex: 3),
      IconButton(
        onPressed: hasPrevEpisode
            ? () {
                if (isFullScreen) {
                  _key.currentState?.exitFullscreen();
                }
                pushReplacementMangaReaderView(
                    context: context,
                    chapter: _streamController.getPrevEpisode());
              }
            : null,
        icon: Icon(
          Icons.skip_previous,
          size: 35,
          color: hasPrevEpisode ? Colors.white : Colors.grey,
        ),
      ),
      const Spacer(),
      const MaterialPlayOrPauseButton(iconSize: 65),
      const Spacer(),
      IconButton(
        onPressed: hasNextEpisode
            ? () {
                if (isFullScreen) {
                  _key.currentState?.exitFullscreen();
                }
                pushReplacementMangaReaderView(
                  context: context,
                  chapter: _streamController.getNextEpisode(),
                );
              }
            : null,
        icon: Icon(Icons.skip_next,
            size: 35, color: hasPrevEpisode ? Colors.white : Colors.grey),
      ),
      const Spacer(flex: 3)
    ];
  }

  Widget _desktopPlayer() {
    MaterialDesktopVideoControlsThemeData materialVideoControlsThemeData(
            bool isFullScreen) =>
        MaterialDesktopVideoControlsThemeData(
            visibleOnMount: true,
            controlsHoverDuration: const Duration(seconds: 2),
            seekBarPositionColor: primaryColor(context),
            seekBarThumbColor: primaryColor(context),
            topButtonBarMargin: const EdgeInsets.all(0),
            bottomButtonBarMargin: const EdgeInsets.all(0),
            topButtonBar: _topButtonBar(context, isFullScreen),
            primaryButtonBar: [
              ValueListenableBuilder<Duration?>(
                  valueListenable: _tempPosition,
                  builder: (context, snapshot, _) {
                    return snapshot != null
                        ? _seekIndicatorTextWidget(
                            snapshot, _currentPosition.value)
                        : const SizedBox.shrink();
                  })
            ],
            buttonBarHeight: 120,
            displaySeekBar: false,
            seekBarThumbSize: 15,
            bottomButtonBar: _desktopBottomButtonBar(context, isFullScreen));
    return MaterialDesktopVideoControlsTheme(
        normal: materialVideoControlsThemeData(false),
        fullscreen: materialVideoControlsThemeData(true),
        child: _videoPlayer(context));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: WillPopScope(
        onWillPop: () async {
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
              overlays: SystemUiOverlay.values);
          Navigator.pop(context);
          return false;
        },
        child: _isDesktop ? _desktopPlayer() : _mobilePlayer(),
      ),
    );
  }
}

Widget _seekIndicatorTextWidget(Duration duration, Duration currentPosition) {
  final swipeDuration = duration.inSeconds;
  final value = currentPosition.inSeconds + swipeDuration;
  return Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Text(
        Duration(seconds: value).label(),
        style: const TextStyle(
            fontSize: 65.0, fontWeight: FontWeight.bold, color: Colors.white),
      ),
      Text(
        "[${swipeDuration > 0 ? "+${Duration(seconds: swipeDuration).label()}" : "-${Duration(seconds: swipeDuration).label()}"}]",
        style: const TextStyle(
            fontSize: 40.0, color: Colors.white, fontWeight: FontWeight.bold),
      ),
    ],
  );
}

class VideoPrefs {
  String? title;
  VideoTrack? videoTrack;
  SubtitleTrack? subtitle;
  AudioTrack? audio;
  bool isLocal;
  final Map<String, String>? headers;
  VideoPrefs(
      {this.videoTrack,
      this.isLocal = true,
      this.headers,
      this.subtitle,
      this.audio,
      this.title});
}
