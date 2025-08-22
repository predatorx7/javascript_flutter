part of 'state.dart';

// ignore: non_constant_identifier_names
String _MESSAGING_SCRIPT(bool useConsoleMessagingHack) => '''
class HostMessenger {
    constructor(name) {
        this.channelName = name;
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
            throw new Error(`Message must be a string, got \${typeof message}`);
        }
        let promise = new Promise((resolve, reject) => {
            const nextId = this.id++;
            this.pendingMessages.push({
                id: nextId,
                message,
                resolve,
                reject
            });
            if (globalThis.JavaScriptAndroid.useConsoleMessagingHack) {
                this.postMessageForConsoleMessagingHack(nextId, message);
            }
        });
        return promise;
    }

    postMessageForConsoleMessagingHack(id, message) {
         // Cannot rely on console messages for the transfer of large volumes of data. Overly large messages, stack traces, or source identifiers may be truncated.
         const messageNotification = JSON.stringify({ tag: 'CONSOLE_MESSAGING_HACK', id, channelName: this.channelName });
         globalThis.JavaScriptAndroid.useConsoleMessagingHack(messageNotification);
    }
}

/// Similar to sendMessage available from ios plugin implementation
globalThis.sendMessage = function(channelName, message) {
  return globalThis.JavaScriptAndroid.HostMessengerRegisteredChannels[channelName].postMessage(message);
}

globalThis.JavaScriptAndroid = {
  HostMessengerRegisteredChannels: {},
  /// Using console.warn because it may be the least used console method.
  useConsoleMessagingHack: $useConsoleMessagingHack ? console.warn : false,
  getPendingMessages: function(channelName) {
    try {
      const registeredChannels = globalThis.JavaScriptAndroid.HostMessengerRegisteredChannels;
      if (registeredChannels[channelName] && registeredChannels[channelName].getPendingMessages) {
        return registeredChannels[channelName].getPendingMessages();
      } else {
        console.error({reason: `Channel \${channelName} is not found`, channel: registeredChannels[channelName] });
      }
      return [];
    } catch (e) {
      console.error(`Error when getting pending messages for channel \${channelName}`, e);
      return [];
    }
  }
}

if (globalThis.JavaScriptAndroid.useConsoleMessagingHack) {
  /// Forward warning level messages to console.info
  console.warn = function (...args) { console.info(`WARNING: `, ...args);}
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
