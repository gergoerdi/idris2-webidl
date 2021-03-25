// Extracted from https://w3c.github.io/mediacapture-main/getusermedia.html#idl-def-mediastream

[Exposed=Window]
interface MediaStream : EventTarget {
  constructor();
  constructor(MediaStream stream);
  constructor(sequence<MediaStreamTrack> tracks);
  readonly attribute DOMString id;
  sequence<MediaStreamTrack> getAudioTracks();
  sequence<MediaStreamTrack> getVideoTracks();
  sequence<MediaStreamTrack> getTracks();
  MediaStreamTrack? getTrackById(DOMString trackId);
  undefined addTrack(MediaStreamTrack track);
  undefined removeTrack(MediaStreamTrack track);
  MediaStream clone();
  readonly attribute boolean active;
  attribute EventHandler onaddtrack;
  attribute EventHandler onremovetrack;
};

[Exposed=Window]
interface MediaStreamTrack : EventTarget {
  readonly attribute DOMString kind;
  readonly attribute DOMString id;
  readonly attribute DOMString label;
  attribute boolean enabled;
  readonly attribute boolean muted;
  attribute EventHandler onmute;
  attribute EventHandler onunmute;
  readonly attribute MediaStreamTrackState readyState;
  attribute EventHandler onended;
  MediaStreamTrack clone();
  undefined stop();
  MediaTrackCapabilities getCapabilities();
  MediaTrackConstraints getConstraints();
  MediaTrackSettings getSettings();
  Promise<undefined> applyConstraints(optional MediaTrackConstraints constraints = {});
};

enum MediaStreamTrackState {
  "live",
  "ended"
};

dictionary MediaTrackSupportedConstraints {
  boolean width = true;
  boolean height = true;
  boolean aspectRatio = true;
  boolean frameRate = true;
  boolean facingMode = true;
  boolean resizeMode = true;
  boolean sampleRate = true;
  boolean sampleSize = true;
  boolean echoCancellation = true;
  boolean autoGainControl = true;
  boolean noiseSuppression = true;
  boolean latency = true;
  boolean channelCount = true;
  boolean deviceId = true;
  boolean groupId = true;
};

dictionary MediaTrackCapabilities {
  ULongRange width;
  ULongRange height;
  DoubleRange aspectRatio;
  DoubleRange frameRate;
  sequence<DOMString> facingMode;
  sequence<DOMString> resizeMode;
  ULongRange sampleRate;
  ULongRange sampleSize;
  sequence<boolean> echoCancellation;
  sequence<boolean> autoGainControl;
  sequence<boolean> noiseSuppression;
  DoubleRange latency;
  ULongRange channelCount;
  DOMString deviceId;
  DOMString groupId;
};

dictionary MediaTrackConstraints : MediaTrackConstraintSet {
  sequence<MediaTrackConstraintSet> advanced;
};

dictionary MediaTrackConstraintSet {
  ConstrainULong width;
  ConstrainULong height;
  ConstrainDouble aspectRatio;
  ConstrainDouble frameRate;
  ConstrainDOMString facingMode;
  ConstrainDOMString resizeMode;
  ConstrainULong sampleRate;
  ConstrainULong sampleSize;
  ConstrainBoolean echoCancellation;
  ConstrainBoolean autoGainControl;
  ConstrainBoolean noiseSuppression;
  ConstrainDouble latency;
  ConstrainULong channelCount;
  ConstrainDOMString deviceId;
  ConstrainDOMString groupId;
};

dictionary MediaTrackSettings {
  long width;
  long height;
  double aspectRatio;
  double frameRate;
  DOMString facingMode;
  DOMString resizeMode;
  long sampleRate;
  long sampleSize;
  boolean echoCancellation;
  boolean autoGainControl;
  boolean noiseSuppression;
  double latency;
  long channelCount;
  DOMString deviceId;
  DOMString groupId;
};

enum VideoFacingModeEnum {
  "user",
  "environment",
  "left",
  "right"
};

enum VideoResizeModeEnum {
  "none",
  "crop-and-scale"
};

[Exposed=Window]
interface MediaStreamTrackEvent : Event {
  constructor(DOMString type, MediaStreamTrackEventInit eventInitDict);
  [SameObject] readonly attribute MediaStreamTrack track;
};

dictionary MediaStreamTrackEventInit : EventInit {
  required MediaStreamTrack track;
};

[Exposed=Window]
interface OverconstrainedError : DOMException {
  constructor(DOMString constraint, optional DOMString message = "");
  readonly attribute DOMString constraint;
};

partial interface Navigator {
  [SameObject, SecureContext] readonly attribute MediaDevices mediaDevices;
};

[Exposed=Window, SecureContext]
interface MediaDevices : EventTarget {
  attribute EventHandler ondevicechange;
  Promise<sequence<MediaDeviceInfo>> enumerateDevices();
};

[Exposed=Window, SecureContext]
interface MediaDeviceInfo {
  readonly attribute DOMString deviceId;
  readonly attribute MediaDeviceKind kind;
  readonly attribute DOMString label;
  readonly attribute DOMString groupId;
  [Default] object toJSON();
};

enum MediaDeviceKind {
  "audioinput",
  "audiooutput",
  "videoinput"
};

[Exposed=Window]
interface InputDeviceInfo : MediaDeviceInfo {
  MediaTrackCapabilities getCapabilities();
};

partial interface Navigator {
  [SecureContext] undefined getUserMedia(MediaStreamConstraints constraints,
                                    NavigatorUserMediaSuccessCallback successCallback,
                                    NavigatorUserMediaErrorCallback errorCallback);
};

partial interface MediaDevices {
  MediaTrackSupportedConstraints getSupportedConstraints();
  Promise<MediaStream> getUserMedia(optional MediaStreamConstraints constraints = {});
};

dictionary MediaStreamConstraints {
  (boolean or MediaTrackConstraints) video = false;
  (boolean or MediaTrackConstraints) audio = false;
};

callback NavigatorUserMediaSuccessCallback = undefined (MediaStream stream);

callback NavigatorUserMediaErrorCallback = undefined (DOMException error);

[Exposed=Window]
interface ConstrainablePattern {
  Capabilities  getCapabilities();
  Constraints   getConstraints();
  Settings      getSettings();
  Promise<undefined> applyConstraints(optional Constraints constraints = {});
};

dictionary DoubleRange {
  double max;
  double min;
};

dictionary ConstrainDoubleRange : DoubleRange {
  double exact;
  double ideal;
};

dictionary ULongRange {
  [Clamp] unsigned long max;
  [Clamp] unsigned long min;
};

dictionary ConstrainULongRange : ULongRange {
  [Clamp] unsigned long exact;
  [Clamp] unsigned long ideal;
};

dictionary ConstrainBooleanParameters {
  boolean exact;
  boolean ideal;
};

dictionary ConstrainDOMStringParameters {
  (DOMString or sequence<DOMString>) exact;
  (DOMString or sequence<DOMString>) ideal;
};

typedef ([Clamp] unsigned long or ConstrainULongRange) ConstrainULong;

typedef (double or ConstrainDoubleRange) ConstrainDouble;

typedef (boolean or ConstrainBooleanParameters) ConstrainBoolean;

typedef (DOMString or
         sequence<DOMString> or
         ConstrainDOMStringParameters) ConstrainDOMString;

dictionary Capabilities {};

dictionary Settings {};

dictionary ConstraintSet {};

dictionary Constraints : ConstraintSet {
  sequence<ConstraintSet> advanced;
};
