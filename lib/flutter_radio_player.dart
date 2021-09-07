/*
 *  flutter_radio_player.dart
 *
 *  Created by Ilya Chirkunov <xc@yar.net> on 28.12.2020.
 */

import 'dart:async';
import 'dart:typed_data';
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

  /// Configure channel
  Future<void> setMediaItem(String title, String url, [String? image]) async {
    await Future.delayed(Duration(milliseconds: 500));
    await _methodChannel.invokeMethod('set', [title, url]);
    if (image != null) setDefaultArtwork(image);
  }

  Future<void> play() async {
    await _methodChannel.invokeMethod('play');
  }

  Future<void> pause() async {
    await _methodChannel.invokeMethod('pause');
  }

  /// Set default artwork
  Future<void> setDefaultArtwork(String image) async {
    await rootBundle.load(image).then((value) {
      _defaultArtworkChannel.send(value);
    });
  }

  Future<void> setArtworkFromUrl(String imageUrl) async {
    http.Response response = await http.get(Uri.parse(imageUrl));
    Uint8List rsp = response.bodyBytes;
    var buffer = rsp.buffer;
    var value = new ByteData.view(buffer);
    _defaultArtworkChannel.send(value);
  }

  /// Get artwork from metadata
  Future<Image?> getMetadataArtwork() async {
    final byteData = await _metadataArtworkChannel.send(ByteData(0));
    if (byteData == null) return null;

    return Image.memory(
      byteData.buffer.asUint8List(),
      key: UniqueKey(),
      fit: BoxFit.cover,
    );
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
}
