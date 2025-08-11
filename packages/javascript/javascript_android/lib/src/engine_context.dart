import 'package:javascript_platform_interface/javascript_platform_interface.dart';

class EngineHostState {
  final Map<String, JavaScriptChannelParams> _enabledChannels = {};

  void addChannel(String channelName, JavaScriptChannelParams channelParams) {
    _enabledChannels[channelName] = channelParams;
  }

  void removeChannel(String channelName) {
    _enabledChannels.remove(channelName);
  }

  void dispose() {
    _enabledChannels.clear();
  }
}
