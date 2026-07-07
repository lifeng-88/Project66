import AVKit
import SwiftUI

struct AssetVideoPlayerView: View {
    let player: AVPlayer

    var body: some View {
        VideoPlayer(player: player)
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.12), radius: 16, y: 8)
    }
}

struct LocalFileVideoPlayerView: View {
    let url: URL

    @State private var player: AVPlayer?

    var body: some View {
        Group {
            if let player {
                AssetVideoPlayerView(player: player)
            } else {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.black.opacity(0.08))
                    .aspectRatio(16 / 9, contentMode: .fit)
                    .overlay(
                        ProgressView()
                    )
            }
        }
        .onAppear {
            guard player == nil else { return }
            player = AVPlayer(url: url)
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
    }
}
