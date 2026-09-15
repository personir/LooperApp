import UIKit
import AVFoundation
import PhotosUI
import MediaPlayer

class ViewController: UIViewController, PHPickerViewControllerDelegate {

    private var player: AVQueuePlayer?
    private var looper: AVPlayerLooper?
    private var playerLayer: AVPlayerLayer?
    private var isLoopingEnabled: Bool = true
    private var selectedVideoURL: URL?

    // UI Elements
    private let videoContainerView = UIView()
    private let controlsStackView = UIStackView()
    private let importButton = UIButton(type: .system)
    private let playPauseButton = UIButton(type: .system)
    private let loopToggleButton = UIButton(type: .system)
    private let statusLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupAudioSession()
        setupUILayout()
        setupRemoteCommandCenter()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        playerLayer?.frame = videoContainerView.bounds
    }

    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .moviePlayback, options: [.mixWithOthers, .allowAirPlay])
            try session.setActive(true)
        } catch {
            print("Audio session configuration error: \(error)")
        }
    }

    private func setupUILayout() {
        videoContainerView.backgroundColor = .clear
        videoContainerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(videoContainerView)

        statusLabel.text = "Import a video to begin playback"
        statusLabel.textColor = .lightGray
        statusLabel.font = .systemFont(ofSize: 16, weight: .regular)
        statusLabel.textAlignment = .center
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(statusLabel)

        importButton.setTitle("Import Video", for: .normal)
        importButton.titleLabel?.font = .boldSystemFont(ofSize: 16)
        importButton.tintColor = .white
        importButton.backgroundColor = UIColor.systemBlue
        importButton.layer.cornerRadius = 10
        importButton.addTarget(self, action: #selector(openPicker), for: .touchUpInside)

        playPauseButton.setTitle("Pause", for: .normal)
        playPauseButton.titleLabel?.font = .boldSystemFont(ofSize: 16)
        playPauseButton.tintColor = .white
        playPauseButton.backgroundColor = UIColor.systemGray
        playPauseButton.layer.cornerRadius = 10
        playPauseButton.isEnabled = false
        playPauseButton.addTarget(self, action: #selector(togglePlayPause), for: .touchUpInside)

        loopToggleButton.setTitle("Loop: ON", for: .normal)
        loopToggleButton.titleLabel?.font = .boldSystemFont(ofSize: 16)
        loopToggleButton.tintColor = .white
        loopToggleButton.backgroundColor = UIColor.systemGreen
        loopToggleButton.layer.cornerRadius = 10
        loopToggleButton.addTarget(self, action: #selector(toggleLooping), for: .touchUpInside)

        controlsStackView.axis = .horizontal
        controlsStackView.distribution = .fillEqually
        controlsStackView.spacing = 12
        controlsStackView.translatesAutoresizingMaskIntoConstraints = false

        controlsStackView.addArrangedSubview(importButton)
        controlsStackView.addArrangedSubview(playPauseButton)
        controlsStackView.addArrangedSubview(loopToggleButton)
        view.addSubview(controlsStackView)

        NSLayoutConstraint.activate([
            videoContainerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            videoContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            videoContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            videoContainerView.bottomAnchor.constraint(equalTo: controlsStackView.topAnchor, constant: -16),

            statusLabel.centerXAnchor.constraint(equalTo: videoContainerView.centerXAnchor),
            statusLabel.centerYAnchor.constraint(equalTo: videoContainerView.centerYAnchor),

            controlsStackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            controlsStackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            controlsStackView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            controlsStackView.heightAnchor.constraint(equalToConstant: 50)
        ])
    }

    @objc private func openPicker() {
        var config = PHPickerConfiguration()
        config.filter = .videos
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        present(picker, animated: true)
    }

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let provider = results.first?.itemProvider, provider.hasItemConformingToTypeIdentifier("public.movie") else { return }

        statusLabel.text = "Loading video..."

        provider.loadFileRepresentation(forTypeIdentifier: "public.movie") { [weak self] url, error in
            guard let self = self, let url = url else { return }
            let tempDirectory = FileManager.default.temporaryDirectory
            let permanentURL = tempDirectory.appendingPathComponent(UUID().uuidString + "_" + url.lastPathComponent)

            try? FileManager.default.removeItem(at: permanentURL)
            do {
                try FileManager.default.copyItem(at: url, to: permanentURL)
                DispatchQueue.main.async {
                    self.selectedVideoURL = permanentURL
                    self.setupPlayerWithURL(permanentURL)
                }
            } catch {
                DispatchQueue.main.async {
                    self.statusLabel.text = "Failed to load video file."
                }
            }
        }
    }

    private func setupPlayerWithURL(_ url: URL) {
        player?.pause()
        looper?.disableLooping()
        playerLayer?.removeFromSuperlayer()

        let item = AVPlayerItem(url: url)
        let queuePlayer = AVQueuePlayer(playerItem: item)

        if isLoopingEnabled {
            looper = AVPlayerLooper(player: queuePlayer, templateItem: item)
        }

        player = queuePlayer

        let layer = AVPlayerLayer(player: queuePlayer)
        layer.frame = videoContainerView.bounds
        layer.videoGravity = .resizeAspect
        videoContainerView.layer.addSublayer(layer)
        playerLayer = layer

        queuePlayer.play()
        playPauseButton.isEnabled = true
        playPauseButton.setTitle("Pause", for: .normal)
        statusLabel.isHidden = true

        updateNowPlayingInfo(filename: url.lastPathComponent)
    }

    @objc private func togglePlayPause() {
        guard let player = player else { return }
        if player.rate != 0 {
            player.pause()
            playPauseButton.setTitle("Play", for: .normal)
        } else {
            player.play()
            playPauseButton.setTitle("Pause", for: .normal)
        }
    }

    @objc private func toggleLooping() {
        isLoopingEnabled.toggle()
        if isLoopingEnabled {
            loopToggleButton.setTitle("Loop: ON", for: .normal)
            loopToggleButton.backgroundColor = UIColor.systemGreen
            if let url = selectedVideoURL {
                setupPlayerWithURL(url)
            }
        } else {
            loopToggleButton.setTitle("Loop: OFF", for: .normal)
            loopToggleButton.backgroundColor = UIColor.systemRed
            looper?.disableLooping()
        }
    }

    private func setupRemoteCommandCenter() {
        let commandCenter = MPRemoteCommandCenter.shared()
        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.player?.play()
            self?.playPauseButton.setTitle("Pause", for: .normal)
            return .success
        }
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.player?.pause()
            self?.playPauseButton.setTitle("Play", for: .normal)
            return .success
        }
    }

    private func updateNowPlayingInfo(filename: String) {
        var nowPlayingInfo = [String: Any]()
        nowPlayingInfo[MPMediaItemPropertyTitle] = filename
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = 1.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
}
