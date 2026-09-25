import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../models/media_item.dart';

class PlaybackService extends ChangeNotifier {
  Player? player;
  VideoController? controller;
  String? mediaId;
  String? episodeId;
  String? title;
  String? subtitle;
  String? streamUrl;
  StreamResult? streamResult;
  String? audioTrack;
  bool isFloating = false;

  void startFloating({
    required Player activePlayer,
    required VideoController activeController,
    required String activeMediaId,
    String? activeEpisodeId,
    required String activeTitle,
    String? activeSubtitle,
    required String activeStreamUrl,
    StreamResult? activeStreamResult,
    String? activeAudioTrack,
  }) {
    player = activePlayer;
    controller = activeController;
    mediaId = activeMediaId;
    episodeId = activeEpisodeId;
    title = activeTitle;
    subtitle = activeSubtitle;
    streamUrl = activeStreamUrl;
    streamResult = activeStreamResult;
    audioTrack = activeAudioTrack;
    isFloating = true;
    notifyListeners();
  }

  void stopFloating() {
    isFloating = false;
    player?.stop();
    player?.dispose();
    player = null;
    controller = null;
    mediaId = null;
    episodeId = null;
    title = null;
    subtitle = null;
    streamUrl = null;
    streamResult = null;
    audioTrack = null;
    notifyListeners();
  }

  void restore() {
    isFloating = false;
    notifyListeners();
  }
}
