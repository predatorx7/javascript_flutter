part of 'state.dart';

const String _MESSAGING_SCRIPT = r'''
class HostMessenger {
    constructor() {
        this.pendingMessages = [];
        this.id = 0;
    }

    getPendingMessages() {
        return this.pendingMessages.map(m => ({id: m.id, message: m.message}));
    }

    removeMessageById(id) {
        this.pendingMessages = this.pendingMessages.filter(m => m.id !== id);
    }

    resolveById(id, response) {
        let message = this.pendingMessages.find(m => m.id === id);
        if (message) {
            message.resolve(response);
            this.removeMessageById(id);
            return true;
        }
        return false;
    }

    rejectById(id, error) {
        let message = this.pendingMessages.find(m => m.id === id);
        if (message) {
            message.reject(error);
            this.removeMessageById(id);
            return true;
        }
        return false;
    }

    postMessage(message) {
        if (typeof message !== 'string') {
            throw new Error(`Message must be a string, got ${typeof message}`);
        }
        let promise = new Promise((resolve, reject) => {
            this.pendingMessages.push({
                id: this.id++,
                message,
                resolve,
                reject
            });
        });
        return promise;
    }
}

globalThis.HostMessengerRegisteredChannels = {}

/// Similar to sendMessage available from ios plugin implementation
globalThis.sendMessage = function(channelName, message) {
  return globalThis.HostMessengerRegisteredChannels[channelName].postMessage(message);
}

globalThis.getPendingMessages = function(channelName) {
  try {
    const registeredChannels = globalThis.HostMessengerRegisteredChannels;
    if (registeredChannels[channelName] && registeredChannels[channelName].getPendingMessages) {
      return registeredChannels[channelName].getPendingMessages();
    } else {
      console.error({reason: `Channel ${channelName} is not found`, channel: registeredChannels[channelName] });
    }
    return [];
  } catch (e) {
    console.error(`Error when getting pending messages for channel $channelName`, e);
    return [];
  }
}
''';

const String _TIMEOUT_SCRIPT = r'''
var __NATIVE_HOST_JS__setTimeoutCount = -1;
var __NATIVE_HOST_JS__setTimeoutCallbacks = {};
function setTimeout(fnTimeout, timeout) {
  try {
    __NATIVE_HOST_JS__setTimeoutCount += 1;
    var timeoutIndex = '' + __NATIVE_HOST_JS__setTimeoutCount;
    __NATIVE_HOST_JS__setTimeoutCallbacks[timeoutIndex] =  fnTimeout;
    sendMessage('SetTimeout', JSON.stringify({ timeoutIndex, timeout}));
  } catch (e) {
    console.error('ERROR HERE', e.message);
  }
};
''';
