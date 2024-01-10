/// This file defines two main types, `MediaPlaylist` and `MultivariantPlaylist`, which correspond to playlist types defined in the HTTP Live Streaming RFC (https://datatracker.ietf.org/doc/html/rfc8216). Both types present a DSL-style API for constructing the playlist. The various types that comprise the DSL serve to encode the expected structure of the playlist as well as detect some cases where values may not be RFC-compliant.

import struct Foundation.CharacterSet
import class Foundation.NSNumber
import class Foundation.NumberFormatter
import struct Foundation.URL

/// A type which enables creating a media playlist per https://datatracker.ietf.org/doc/html/rfc8216#section-4.3.3, using a DSL-style API.
public struct MediaPlaylist {
  /// `Component` is an opaque type that exists to provide an API to the user for constructing a media playlist.
  public struct Component {

    /// https://datatracker.ietf.org/doc/html/rfc8216#section-4.3.1.1
    public static let header: Component = .tag("EXTM3U")

    /// https://datatracker.ietf.org/doc/html/rfc8216#section-4.3.1.2
    /// Version differences: https://datatracker.ietf.org/doc/html/rfc8216#section-7
    public static func version(_ number: DecimalInteger) -> Component {
      .tag(
        "EXT-X-VERSION",
        attributes:
          "\(number)")
    }

    /// https://datatracker.ietf.org/doc/html/rfc8216#section-4.3.3.1
    public static func targetDuration(_ duration: DecimalInteger) -> Component {
      .tag(
        "EXT-X-TARGETDURATION",
        attributes:
          "\(duration)")
    }

    /// https://datatracker.ietf.org/doc/html/rfc8216#section-4.3.3.2
    public static func mediaSequence(_ number: DecimalInteger) -> Component {
      .tag(
        "EXT-X-MEDIA-SEQUENCE",
        attributes:
          "\(number)")
    }

    /// https://datatracker.ietf.org/doc/html/rfc8216#section-4.3.3.5
    public static func playlistType(_ type: PlaylistType) -> Component {
      .tag(
        "EXT-X-PLAYLIST-TYPE",
        attributes:
          "\(type.attributeValue)")
    }

    /// https://datatracker.ietf.org/doc/html/rfc8216#section-4.3.2
    public static func mediaSegment(tags: [MediaSegmentTag], uri: URI) -> Component {
      Component(
        kind: .mediaSegment(
          tags: tags,
          uri: uri))
    }

    /// https://datatracker.ietf.org/doc/html/rfc8216#section-4.3.3.4
    public static let endlist: Component = .tag("EXT-X-ENDLIST")

    /// Convenience function for creating a tag component
    private static func tag(_ name: StaticString, attributes: AttributeFragment? = nil) -> Component
    {
      Component(kind: .tag(GenericTag(name, attributes: attributes)))
    }

    fileprivate var strings: [CompliantString] {
      switch kind {
      case .tag(let tag):
        [tag.compliantString]
      case .mediaSegment(let tags, let uri):
        tags.map(\.tag.compliantString) + [CompliantString(uri)]
      }
    }

    /// Components are currently opaque to the user, but internally they can be either  tags and media segments, as represented by their `kind`.
    private enum Kind {
      case tag(GenericTag)
      case mediaSegment(tags: [MediaSegmentTag], uri: URI)
    }
    private let kind: Kind
  }

  /// A Media Segment Tag as defined in https://datatracker.ietf.org/doc/html/rfc8216#section-4.3.2
  /// One peculiar quality of media segment tags that is worth calling out is a media segment tag may apply to all following media segments (or until a media segment contains the same tag). We expect users of this API to be familiar with the peculiarity and do nothing to mitigate it.
  public struct MediaSegmentTag {

    /// https://datatracker.ietf.org/doc/html/rfc8216#section-4.3.2.5
    /// Specifies how to obtain the Media Initialization Section
    public static func map(uri: URI, length: DecimalInteger, start: DecimalInteger)
      -> MediaSegmentTag
    {
      return .tag(
        "EXT-X-MAP",
        attributes: .attributeList([
          "URI": "\(uri)" as QuotedString,
          /// While this is similar to the byte range in the `EXT-X-BYTERANGE` tag, it is not the same as it must contain a start offset, which is optional in the `EXT-X-BYTERANGE` tag.
          "BYTERANGE": "\(length)@\(start)" as QuotedString,
        ]))
    }

    /// https://datatracker.ietf.org/doc/html/rfc8216#section-4.3.2.2
    public static func byteRange(length: DecimalInteger, start: DecimalInteger? = nil)
      -> MediaSegmentTag
    {
      .tag(
        "EXT-X-BYTERANGE",
        attributes: start.map { "\(length)@\($0)" } ?? "\(length)")
    }

    /// https://datatracker.ietf.org/doc/html/rfc8216#section-4.3.2.1
    public static func inf(duration: DecimalInteger) -> MediaSegmentTag {
      .tag(
        "EXTINF",
        /// INF allows a human-readable title after the duration which we don't currently provide API for
        attributes: "\(duration),")
    }
    public static func inf(duration: DecimalFloatingPoint) -> MediaSegmentTag {
      .tag(
        "EXTINF",
        /// INF allows a human-readable title after the duration which we don't currently provide API for
        attributes: "\(duration),")
    }

    /// Convenience function for creating a tag component
    private static func tag(_ name: StaticString, attributes: AttributeFragment? = nil)
      -> MediaSegmentTag
    {
      MediaSegmentTag(tag: GenericTag(name, attributes: attributes))
    }
    fileprivate let tag: GenericTag
  }

  public struct PlaylistType {
    public static let videoOnDemand: PlaylistType = PlaylistType(attributeValue: "VOD")

    fileprivate let attributeValue: EnumeratedString
  }

  public init(_ components: [Component]) {
    self.components = components
  }

  public var stringValue: String {
    components
      .flatMap(\.strings)
      .map { "\($0.normalizedForm)\n" }
      .joined()
  }

  private let components: [Component]
}

/// A type which enables creating a multivariant playlist per https://datatracker.ietf.org/doc/html/rfc8216#section-4.3.3, using a DSL-style API.
public struct MultivariantPlaylist {

  /// A component of a multivariant playlist
  /// - note: We currently duplicate "Basic Tags" which can appear both in a media playlist and a multivariant playlist to lower the complexity of the implementation.
  public struct Component {
    /// https://datatracker.ietf.org/doc/html/rfc8216#section-4.3.1.1
    public static let header: Component = .tag("EXTM3U")

    /// https://datatracker.ietf.org/doc/html/rfc8216#section-4.3.1.2
    /// Version differences: https://datatracker.ietf.org/doc/html/rfc8216#section-7
    public static func version(_ number: DecimalInteger) -> Component {
      .tag(
        "EXT-X-VERSION",
        attributes:
          "\(number)")
    }

    /// https://datatracker.ietf.org/doc/html/rfc8216#section-4.3.5.1
    public static let independentSegments: Component = .tag("EXT-X-INDEPENDENT-SEGMENTS")

    /// https://datatracker.ietf.org/doc/html/rfc8216#section-4.3.4.1
    public static func media(
      type: MediaType,
      groupID: QuotedString,
      channels: QuotedString,
      language: QuotedString,
      name: QuotedString,
      isDefault: Bool,
      uri: URI
    ) -> Component {
      .tag(
        "EXT-X-MEDIA",
        attributes: .attributeList([
          "TYPE": type.attributeValue,
          "GROUP-ID": groupID,
          "CHANNELS": channels,
          "LANGUAGE": language,
          "NAME": name,
          "DEFAULT": EnumeratedString.yesOrNo(isDefault),
          "URI": "\(uri)" as QuotedString,
        ]))
    }
    public struct MediaType {
      public static let audio = MediaType(attributeValue: "AUDIO")
      fileprivate let attributeValue: EnumeratedString
    }

    /// https://datatracker.ietf.org/doc/html/rfc8216#section-4.3.4.2
    public static func streamInf(
      bandwidth: DecimalInteger,
      frameRate: DecimalFloatingPoint,
      audio: QuotedString,
      resolution: DecimalResolution,
      codecs: QuotedString,
      uri: URI
    ) -> Component {
      return Component(
        kind: .variantStream(
          GenericTag(
            "EXT-X-STREAM-INF",
            attributes: .attributeList([
              "BANDWIDTH": bandwidth,
              "FRAME-RATE": frameRate,
              "AUDIO": audio,
              "RESOLUTION": resolution,
              "CODECS": codecs,
            ])),
          uri))
    }

    /// Convenience function for creating a tag component
    private static func tag(_ name: StaticString, attributes: AttributeFragment? = nil) -> Component
    {
      Component(kind: .tag(GenericTag(name, attributes: attributes)))
    }

    fileprivate var strings: [CompliantString] {
      switch kind {
      case .tag(let tag):
        [tag.compliantString]
      case .variantStream(let tag, let uri):
        [tag.compliantString, CompliantString(uri)]
      }
    }

    /// Components are currently opaque to the user, but internally they can be either a tag or a variant stream (which is a tag followed by a URI).
    private enum Kind {
      case tag(GenericTag)
      case variantStream(GenericTag, URI)
    }
    private let kind: Kind
  }
  public init(_ components: [Component]) {
    self.components = components
  }

  public var stringValue: String {
    components
      .flatMap(\.strings)
      .map { "\($0.normalizedForm)\n" }
      .joined()
  }

  private let components: [Component]
}

// MARK: - Value Types

/// A URI that can appear in a media playlist.
/// https://datatracker.ietf.org/doc/html/rfc3986
public struct URI {
  public init(_ string: String) throws {
    guard let url = URL(string: string) else {
      throw Error.invalidURI(string)
    }
    self.url = url
  }
  public init(url: URL) {
    self.url = url
  }

  fileprivate let url: URL
  private enum Error: Swift.Error {
    case invalidURI(String)
  }
}

/// Represents a `decimal-integer` as defined in https://datatracker.ietf.org/doc/html/rfc8216#section-4.2
public struct DecimalInteger: AttributeValue, ExpressibleByIntegerLiteral {
  public init(integerLiteral value: UInt64) {
    self.init(value)
  }
  public init(_ value: UInt64) {
    /// All values representable by`UInt64` are compliant
    compliantString = CompliantString(value)
  }
  public init(_ string: String) throws {
    guard let uint64 = UInt64(string) else {
      throw Error.valueIsNotRepresentableAsUInt64(string)
    }
    self.init(uint64)
  }
  public init<T: BinaryInteger>(_ value: T) throws {
    guard let uint64 = UInt64(exactly: value) else {
      throw Error.valueIsNotRepresentableAsUInt64(String(value))
    }
    self.init(uint64)
  }

  fileprivate let compliantString: CompliantString

  private enum Error: Swift.Error {
    case valueIsNotRepresentableAsUInt64(String)
  }
}

/// Represents a `decimal-floating-point` as defined in https://datatracker.ietf.org/doc/html/rfc8216#section-4.2
public struct DecimalFloatingPoint: AttributeValue, ExpressibleByFloatLiteral {
  public init(floatLiteral value: Double) {
    compliantString = CompliantString(value)
  }
  public init(_ value: Double) throws {
    try self.init("\(value)")
  }
  public init(_ string: String) throws {
    compliantString = try CompliantString(string)
    let invalidCharacters = compliantString.normalizedForm
      .unicodeScalars
      .filter(Self.invalidCharacters.contains)
    guard invalidCharacters.isEmpty else {
      throw Error.containsInvalidCharacters(string, invalidCharacters)
    }
    guard Double(compliantString.normalizedForm) != nil else {
      throw Error.notRepresentableAsDouble(string)
    }
  }

  fileprivate let compliantString: CompliantString

  private enum Error: Swift.Error {
    case containsInvalidCharacters(String, String.UnicodeScalarView)
    case notRepresentableAsDouble(String)
  }
  private static let invalidCharacters = CharacterSet(charactersIn: "0123456789.").inverted
}

/// Represents a `quoted-string` as defined in https://datatracker.ietf.org/doc/html/rfc8216#section-4.2
public struct QuotedString: AttributeValue {
  public init(_ string: String) throws {
    try self.init(CompliantString(string))
  }

  fileprivate init(_ string: CompliantString) throws {
    let invalidCharacters = string.normalizedForm
      .unicodeScalars
      .filter(Self.invalidCharacters.contains)
    guard invalidCharacters.isEmpty else {
      throw Error.containsInvalidCharacters(string.normalizedForm, invalidCharacters)
    }
    unquotedString = string
  }
  fileprivate var compliantString: CompliantString { "\"\(unquotedString)\"" }

  private let unquotedString: CompliantString

  private enum Error: Swift.Error {
    case containsInvalidCharacters(String, String.UnicodeScalarView)
  }
  private static let invalidCharacters = CharacterSet(charactersIn: "\n\"")
}

extension QuotedString: ExpressibleByStringInterpolation {
  public init(stringLiteral value: StaticString) {
    /// We trust that compile-time literals won't contain quotes
    try! self.init(CompliantString(stringLiteral: value))
  }

  /// We can construct a `QuotedString` via string interoplation of values we know will not contain quotes
  public init(stringInterpolation: StringInterpolation) {
    unquotedString = stringInterpolation.components.joined()
  }
  public struct StringInterpolation: StringInterpolationProtocol {
    public init(literalCapacity: Int, interpolationCount: Int) {
      components.reserveCapacity(literalCapacity + interpolationCount)
    }
    public mutating func appendLiteral(_ literal: StaticString) {
      append(trustingIsValid: CompliantString(stringLiteral: literal))
    }
    /// Quotes are not valid characters in a URI
    public mutating func appendInterpolation(_ uri: URI) {
      append(trustingIsValid: CompliantString(uri))
    }
    /// Quotes are not a valid character in a decimal-integer
    public mutating func appendInterpolation(_ value: DecimalInteger) {
      append(trustingIsValid: value.compliantString)
    }
    /// Quotes are not a valid character in an `Int`
    public mutating func appendInterpolation(_ value: Int) {
      append(trustingIsValid: CompliantString(value))
    }
    /// Quoted strings are interpolated without the surrounding quotes
    public mutating func appendInterpolation(_ value: QuotedString) {
      append(trustingIsValid: value.unquotedString)
    }

    /// For certain values, we trust that they do not have newlines or double-quotes.
    private mutating func append(trustingIsValid string: CompliantString) {
      /// When assertions are enabled, verify `string` is valid
      assert(
        string.normalizedForm
          .unicodeScalars
          .filter(QuotedString.invalidCharacters.contains)
          .isEmpty)
      components.append(string)
    }
    fileprivate var components: [CompliantString] = []
  }
}

/// Represents a `enumerated-string` as defined in https://datatracker.ietf.org/doc/html/rfc8216#section-4.2
/// Enumerated strings should be one of a known set values, so this type is private (meaning the values must be declared in this file) and we use `StaticString` to enforce that these are compile-time constants.
private struct EnumeratedString: AttributeValue, ExpressibleByStringLiteral {
  init(stringLiteral value: StaticString) {
    self.compliantString = "\(value)"
  }

  static func yesOrNo(_ isYes: Bool) -> EnumeratedString {
    isYes ? "YES" : "NO"
  }

  fileprivate let compliantString: CompliantString
}

/// Represents a `decimal-resolution` as defined in https://datatracker.ietf.org/doc/html/rfc8216#section-4.2
public struct DecimalResolution: AttributeValue {
  public init(width: DecimalInteger, height: DecimalInteger) {
    compliantString = "\(width.compliantString)x\(height.compliantString)"
  }

  fileprivate let compliantString: CompliantString
}

// MARK: - DSL Implementation Details

/// A protocol representing a value which can appear in an attribute list per https://datatracker.ietf.org/doc/html/rfc8216#section-4.2
private protocol AttributeValue {
  var compliantString: CompliantString { get }
}

/// Represents the portion of a tag that follows the optional colon after the tag name. This could either be an attribute list, as defined in https://datatracker.ietf.org/doc/html/rfc8216#section-4.2 or a specific per-tag format, such as for [EXT-X-BYTERANGE](https://datatracker.ietf.org/doc/html/rfc8216#section-4.3.2.2).
private struct AttributeFragment {
  let compliantString: CompliantString
}

private typealias AttributeList = KeyValuePairs<CompliantString, AttributeValue>

/// API for constructing an [Attribute List](https://datatracker.ietf.org/doc/html/rfc8216#section-4.2) style `AttributeFragment` using key-value pairs, which can be expressed as a dictionary literal like `["BANDWIDTH": DecimalInteger(566000)]`.
extension AttributeFragment {
  static func attributeList(_ elements: AttributeList) -> AttributeFragment {
    self.init(attributeList: elements)
  }
  static func attributeList<S: Sequence>(_ elements: S) -> AttributeFragment
  where S.Element == KeyValuePairs<CompliantString, AttributeValue>.Element {
    AttributeFragment(attributeList: elements)
  }
  private init<S: Sequence>(attributeList: S)
  where S.Element == KeyValuePairs<CompliantString, AttributeValue>.Element {
    self.compliantString =
      attributeList
      .map { "\($0.0)=\($0.1.compliantString)" }
      .joined(separator: ",")
  }
}

/// API for constructing an `AttributeFragment` via string interpolation, such as `"\(end)@\(start)"` for [EXT-X-BYTERANGE](https://datatracker.ietf.org/doc/html/rfc8216#section-4.3.2.2).
extension AttributeFragment: ExpressibleByStringInterpolation {
  init(stringLiteral value: StaticString) {
    fatalError("AttributeFragment should contain at least one interpolated attriubte")
  }
  init(stringInterpolation: StringInterpolation) {
    self.compliantString = stringInterpolation.components.joined()
  }
  struct StringInterpolation: StringInterpolationProtocol {
    init(literalCapacity: Int, interpolationCount: Int) {
      components.reserveCapacity(literalCapacity + interpolationCount)
    }
    mutating func appendLiteral(_ literal: StaticString) {
      components.append(CompliantString(stringLiteral: literal))
    }
    mutating func appendInterpolation(_ value: AttributeValue) {
      components.append(value.compliantString)
    }
    fileprivate var components: [CompliantString] = []
  }
}

/// `GenericTag` encodes the format of any tag that can appear in either a Media Segment, Media Playlist, or Multivariant Playlist. Users should never deal with `GenericTags` and instead should use API on the DSL types which enable creation of only the types of tags that are valid in a specific context.
private struct GenericTag {
  init(_ name: StaticString, attributes: AttributeFragment? = nil) {
    if let attributes = attributes {
      self.compliantString = "#\(name):\(attributes.compliantString)"
    } else {
      self.compliantString = "#\(name)"
    }
  }

  fileprivate let compliantString: CompliantString
}

// MARK: - Compliant Strings

/// A `CompliantString` is a `String` which enforces invariants from https://datatracker.ietf.org/doc/html/rfc8216#section-4.1
/// `CompliantString`s arech checked for compliance at construction, which allows the user to create a variety of `CompliantString`s (or, more accurately, a variety of values backed by `CompliantString`) in a context where they can handle errors in a unified manner (such as decoding), then combine them into a playlist without needing to do any further error checking.
/// - note: The spec allows explicitly allows for `\r` and `\n`, but we disallow these in `CompliantString` as it is intended to represent a segment that does not span multiple lines, and this way we don't need to test for newlines in types backed by `CompliantString`
private struct CompliantString {
  init(_ string: String) throws {
    /// Ensure the line has no control characters
    let controlCharacters = string
      .unicodeScalars
      .filter(Self.invalidCharacters.contains)
    guard controlCharacters.isEmpty else {
      throw Error.lineContainsInvalidCharacters(string, controlCharacters)
    }

    /// Convert to Normal Form C, per the RFC specification
    normalizedForm = string.precomposedStringWithCanonicalMapping
  }
  let normalizedForm: String

  /// Construct a `CompliantString` from a `URI`
  init(_ uri: URI) {
    self.init(trustingIsValid: uri.url.absoluteString)
  }

  /// Construct a `CompliantString` from an integer
  init<T: BinaryInteger>(_ value: T) {
    self.init(trustingIsValid: String(value))
  }

  /// Construct a `CompliantString` from a `Double`
  init(_ value: Double) {
    self.init(trustingIsValid: String(value))
  }

  private init(trustingIsValid value: String) {
    /// Trust, but verify when assertions are enabled
    assert(
      {
        do {
          _ = try CompliantString(value)
          return true
        } catch {
          return false
        }
      }())
    normalizedForm = value
  }

  private enum Error: Swift.Error {
    case lineContainsInvalidCharacters(String, String.UnicodeScalarView)
  }
  private static let invalidCharacters = CharacterSet.controlCharacters
}

extension CompliantString: ExpressibleByStringInterpolation {
  init(stringLiteral value: StaticString) {
    /// We trust that compile-time constants (`StaticString`) will not violate the RFC spec
    try! self.init(String(describing: value))
  }

  /// We can use string interpolation to construct a `CompliantString` from other `CompliantString`s without needing to handle  errors.
  init(stringInterpolation: StringInterpolation) {
    self = stringInterpolation.components.joined()
  }
  struct StringInterpolation: StringInterpolationProtocol {
    init(literalCapacity: Int, interpolationCount: Int) {
      components.reserveCapacity(literalCapacity + interpolationCount)
    }
    mutating func appendLiteral(_ literal: StaticString) {
      components.append(CompliantString(stringLiteral: literal))
    }
    mutating func appendInterpolation(_ literal: StaticString) {
      components.append(CompliantString(stringLiteral: literal))
    }
    mutating func appendInterpolation(_ value: CompliantString) {
      components.append(value)
    }
    var components: [CompliantString] = []
  }
}

extension CompliantString {
  /// Creates a `CompliantString` by joining a sequence of `CompliantString`
  init(joining array: [CompliantString], separator: CompliantString? = nil) {
    /// We don't need to reverify the newly created string, since complliance is achieved by not having invalid characters
    if let separator = separator {
      normalizedForm = array.map(\.normalizedForm).joined(separator: separator.normalizedForm)
    } else {
      normalizedForm = array.map(\.normalizedForm).joined()
    }
  }
}

extension Array where Element == CompliantString {
  /// Join a sequence of `CompliantString`s into a single `CompliantString`
  func joined(separator: CompliantString? = nil) -> CompliantString {
    return CompliantString(joining: self, separator: separator)
  }
}
