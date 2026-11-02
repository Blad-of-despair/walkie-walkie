Map<String, dynamic> createRegister(String nickname) => {
  'type': 'register',
  'nickname': nickname,
};

Map<String, dynamic> createCallOffer(String target, Map<String, dynamic> sdp) => {
  'type': 'call-offer',
  'target': target,
  'sdp': sdp,
};

Map<String, dynamic> createCallAnswer(String target, Map<String, dynamic> sdp) => {
  'type': 'call-answer',
  'target': target,
  'sdp': sdp,
};

Map<String, dynamic> createIceCandidate(String target, Map<String, dynamic> candidate) => {
  'type': 'ice-candidate',
  'target': target,
  'candidate': candidate,
};

Map<String, dynamic> createTalkingStart(String target) => {
  'type': 'talking-start',
  'target': target,
};

Map<String, dynamic> createTalkingStop() => {
  'type': 'talking-stop',
};

String? getMessageType(Map<String, dynamic> msg) => msg['type'] as String?;
