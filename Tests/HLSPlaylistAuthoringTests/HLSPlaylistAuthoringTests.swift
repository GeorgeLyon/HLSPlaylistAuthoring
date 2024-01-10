import XCTest

@testable import HLSPlaylistAuthoring

final class HLSPlaylistAuthoringTests: XCTestCase {
  func testVideoPlaylist() throws {
    let uri = try URI("mock-uri://host/path")
    let playlist = MediaPlaylist([
      .header,
      .version(8),
      .targetDuration(42),
      .mediaSequence(0),
      .playlistType(.videoOnDemand),
      .mediaSegment(
        tags: [
          .map(uri: uri, length: 1000, start: 0),
          .byteRange(length: 20_000, start: 1000),
          .inf(duration: 42),
        ],
        uri: uri),
      .endlist,
    ])

    XCTAssertEqual(
      playlist.stringValue,
      """
      #EXTM3U
      #EXT-X-VERSION:8
      #EXT-X-TARGETDURATION:42
      #EXT-X-MEDIA-SEQUENCE:0
      #EXT-X-PLAYLIST-TYPE:VOD
      #EXT-X-MAP:URI="mock-uri://host/path",BYTERANGE="1000@0"
      #EXT-X-BYTERANGE:20000@1000
      #EXTINF:42,
      mock-uri://host/path
      #EXT-X-ENDLIST

      """)
  }

  func testMultivariantPlaylist() throws {
    let playlist = MultivariantPlaylist([
      .header,
      .version(8),
      .independentSegments,
      .media(
        type: .audio,
        groupID: "AudioGroupID",
        channels: "2",
        language: "en",
        name: "English",
        isDefault: true,
        uri: try URI("mock-uri://host/path")),
      .streamInf(
        bandwidth: 600_000,
        frameRate: try DecimalFloatingPoint("25.000"),
        audio: "AudioGroupID",
        resolution: DecimalResolution(width: 270, height: 480),
        codecs: "video-codec,audio-codec",
        uri: try URI("mock-uri://host/path")),
    ])

    let expected = """
      #EXTM3U
      #EXT-X-VERSION:8
      #EXT-X-INDEPENDENT-SEGMENTS
      #EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="AudioGroupID",CHANNELS="2",LANGUAGE="en",NAME="English",DEFAULT=YES,URI="mock-uri://host/path"
      #EXT-X-STREAM-INF:BANDWIDTH=600000,FRAME-RATE=25.000,AUDIO="AudioGroupID",RESOLUTION=270x480,CODECS="video-codec,audio-codec"
      mock-uri://host/path

      """
    XCTAssertEqual(playlist.stringValue, expected)
  }

  func testErrors() {
    XCTAssertThrowsError(try DecimalFloatingPoint("123.123.123"))
    XCTAssertThrowsError(try QuotedString(String("\"")))
  }
}
