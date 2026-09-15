import UIKit
import AVFoundation
import PhotosUI

class ViewController: UIViewController, PHPickerViewControllerDelegate {

    var player: AVQueuePlayer?
    var looper: AVPlayerLooper?
    var playerLayer: AVPlayerLayer?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupAudioSession()
        setupUI()
    }

    func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback, options: [])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to configure background audio: \(error)")
        }
    }

    func setupUI() {
        let button = UIButton(type: .system)
        button.setTitle("Import Video", for: .normal)
        button.titleLabel?.font = .boldSystemFont(ofSize: 20)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = .systemBlue
        button.layer.cornerRadius = 12
        button.frame = CGRect(x: (view.frame.width - 200) / 2, y: (view.frame.height - 50) / 2, width: 200, height: 50)
        button.addTarget(self, action: #selector(openPicker), for: .touchUpInside)
        view.addSubview(button)
    }

    @objc func openPicker() {
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

        provider.loadFileRepresentation(forTypeIdentifier: "public.movie") { url, error in
            guard let url = url else { return }
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(url.lastPathComponent)
            try? FileManager.default.removeItem(at: tempURL)
            try? FileManager.default.copyItem(at: url, to: tempURL)

            DispatchQueue.main.async {
                self.playAndLoopVideo(url: tempURL)
            }
        }
    }

    func playAndLoopVideo(url: URL) {
        playerLayer?.removeFromSuperlayer()

        let item = AVPlayerItem(url: url)
        let queuePlayer = AVQueuePlayer(playerItem: item)
        looper = AVPlayerLooper(player: queuePlayer, templateItem: item)
        player = queuePlayer

        playerLayer = AVPlayerLayer(player: queuePlayer)
        playerLayer?.frame = view.bounds
        playerLayer?.videoGravity = .resizeAspect
        
        if let layer = playerLayer {
            view.layer.addSublayer(layer)
        }

        player?.play()
    }
}