/*
 *  FlutterRadioPlayer.swift
 *
 *  Created by Ilya Chirkunov <xc@yar.net> on 10.01.2021.
 */

import MediaPlayer
import AVKit

class FlutterRadioPlayer: NSObject, AVPlayerItemMetadataOutputPushDelegate {
    private var player: AVPlayer!
    private var playerItem: AVPlayerItem!
    private var metadata: Array<String>!
    var defaultArtwork: UIImage?
    var metadataArtwork: UIImage?

    func setMediaItem(_ streamTitle: String, _ streamUrl: String) {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [MPMediaItemPropertyTitle: streamTitle, ]
        defaultArtwork = nil
        metadataArtwork = nil
        playerItem = AVPlayerItem(url: URL(string: streamUrl)!)

        if (player == nil) {
            // Create an AVPlayer.
            player = AVPlayer(playerItem: playerItem)
            player.addObserver(self, forKeyPath: #keyPath(AVPlayer.timeControlStatus), options: [.new], context: nil)
            runInBackground()
        } else {
            player.replaceCurrentItem(with: playerItem)
        }
        print(player);

        // Set metadata handler.
        let metaOutput = AVPlayerItemMetadataOutput(identifiers: nil)
        metaOutput.setDelegate(self, queue: DispatchQueue.main)
        playerItem.add(metaOutput)
    }

    func setArtwork(_ image: UIImage?) {
        guard let image = image else { return }

        let artwork = MPMediaItemArtwork(boundsSize: image.size) { (size) -> UIImage in image }
        MPNowPlayingInfoCenter.default().nowPlayingInfo?.updateValue(artwork, forKey: MPMediaItemPropertyArtwork)
    }

    func play() {
        player.play()
    }

    func pause() {
        player.pause()
    }

    func runInBackground() {
        try? AVAudioSession.sharedInstance().setActive(true)
        try? AVAudioSession.sharedInstance().setCategory(.playback)

        // Control buttons on the lock screen.
        UIApplication.shared.beginReceivingRemoteControlEvents()
        let commandCenter = MPRemoteCommandCenter.shared()

        // Play button.
        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { [weak self] (event) -> MPRemoteCommandHandlerStatus in
            self?.play()
            return .success
        }

        // Pause button.
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { [weak self] (event) -> MPRemoteCommandHandlerStatus in
            self?.pause()
            return .success
        }
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        guard let observedKeyPath = keyPath, object is AVPlayer, observedKeyPath == #keyPath(AVPlayer.timeControlStatus) else {
            return
        }

        if let statusAsNumber = change?[NSKeyValueChangeKey.newKey] as? NSNumber {
            let status = AVPlayer.TimeControlStatus(rawValue: statusAsNumber.intValue)

            if status == .paused {
                NotificationCenter.default.post(name: NSNotification.Name(rawValue: "state"), object: nil, userInfo: ["state": false])
            } else if status == .waitingToPlayAtSpecifiedRate {
                NotificationCenter.default.post(name: NSNotification.Name(rawValue: "state"), object: nil, userInfo: ["state": true])
            }
        }
    }

    func metadataOutput(_ output: AVPlayerItemMetadataOutput, didOutputTimedMetadataGroups groups: [AVTimedMetadataGroup],
                from track: AVPlayerItemTrack?) {
        let metaDataItems = groups.first.map({ $0.items })

        // Parse title
        guard let title = metaDataItems?.first?.stringValue else { return }
        metadata = title.components(separatedBy: " - ")
        if (metadata.count == 1) { metadata.append("") }

        // Parse artwork
        metaDataItems!.count > 1 ? metadata.append(metaDataItems![1].stringValue!) : metadata.append("")

        // Update the now playing info
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [
                MPMediaItemPropertyArtist: metadata[0], MPMediaItemPropertyTitle: metadata[1], ]

        metadataArtwork = downloadImage(metadata[2])
        setArtwork(metadataArtwork ?? defaultArtwork)

        // Send metadata to client
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "metadata"), object: nil, userInfo: ["metadata": metadata!])
    }

    func downloadImage(_ value: String) -> UIImage? {
        guard let url = URL(string: value) else { return nil }

        var result: UIImage?
        let semaphore = DispatchSemaphore(value: 0)

        let task = URLSession.shared.dataTask(with: url) { (data, response, error) in
            if let data = data, error == nil { 
                result = UIImage(data: data)
            }
            semaphore.signal()
        }
        task.resume()

        _ = semaphore.wait(timeout: .distantFuture)
        return result
    }
}
