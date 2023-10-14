/*
 *  flutter_radio_player.dart
 *
 *  Created by Ilya Chirkunov <xc@yar.net> on 28.12.2020.
 * Edited by Sebastián Solar on 17.06.2023
 */

import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class FlutterRadioPlayer {
  static const _methodChannel = MethodChannel('flutter_radio_player');
  static const _metadataEvents =
      EventChannel('flutter_radio_player/metadataEvents');
  static const _stateEvents = EventChannel('flutter_radio_player/stateEvents');

  static const _defaultArtworkChannel =
      BasicMessageChannel("flutter_radio_player/setArtwork", BinaryCodec());
  static const _metadataArtworkChannel =
      BasicMessageChannel("flutter_radio_player/getArtwork", BinaryCodec());

  Stream<bool>? _stateStream;
  Stream<List<String>>? _metadataStream;
  bool _isInitialized = false;
  bool _isPlaying = false;

  /// Set new streaming URL.
  Future<void> setChannel(
      {required String title, required String url, String? imagePath}) async {
    await Future.delayed(Duration(milliseconds: 500));
    await _methodChannel.invokeMethod('set', [title, url]);

    if (imagePath != null) setDefaultArtwork(imagePath);
  }

  Future<void> play() async {
    await _methodChannel.invokeMethod('play');
    _isPlaying = true;
  }

  Future<void> stop() async {
    await _methodChannel.invokeMethod('pause');
    _isPlaying = false;
  }

  Future<void> pause() async {
    await _methodChannel.invokeMethod('pause');
    _isPlaying = false;
  }

  /// Set the default image in the notification panel
  Future<void> setDefaultArtwork(String image) async {
    final byteData = image.startsWith('http')
        ? await NetworkAssetBundle(Uri.parse(image)).load(image)
        : await rootBundle.load(image);

    _defaultArtworkChannel.send(byteData);
  }

  // Set atwork from URL
  Future<void> setArtworkFromUrl(String imageUrl) async {
    http.Response response = await http.get(Uri.parse(imageUrl));
    Uint8List rsp = response.bodyBytes;
    var buffer = rsp.buffer;
    var value = new ByteData.view(buffer);
    _defaultArtworkChannel.send(value);
  }

  /// Helps avoid conflicts with custom metadata.
  Future<void> ignoreIcyMetadata() async {
    await _methodChannel.invokeMethod('ignore_icy');
  }

  /// Parse album covers from iTunes.
  Future<void> itunesArtworkParser(bool enable) async {
    await _methodChannel.invokeMethod('itunes_artwork_parser', enable);
  }

  /// Set custom metadata.
  Future<void> setCustomMetadata(List<String> metadata) async {
    await _methodChannel.invokeMethod('metadata', metadata);
  }

  /// Returns the album cover if it has already been downloaded.
  Future<Image?> getArtworkImage() async {
    final byteData = await _metadataArtworkChannel.send(ByteData(0));
    Image? image;

    if (byteData != null)
      image = Image.memory(byteData.buffer.asUint8List(),
          key: UniqueKey(), fit: BoxFit.cover);

    return image;
  }

  /// Get the playback state stream.
  Stream<bool> get stateStream {
    _stateStream ??=
        _stateEvents.receiveBroadcastStream().map<bool>((value) => value);

    return _stateStream!;
  }

  /// Get the metadata stream.
  Stream<List<String>> get metadataStream {
    _metadataStream ??=
        _metadataEvents.receiveBroadcastStream().map((metadata) {
      return metadata.map<String>((value) => value as String).toList();
    });

    return _metadataStream!;
  }

  /// Método para verificar si está inicializado
  bool isInitialized() {
    return _isInitialized;
  }

  /// Método para verificar si está en reproducción
  bool isPlaying() {
    return _isPlaying;
  }
}
