part of 'state.dart';

// ignore: non_constant_identifier_names
String _MESSAGING_SCRIPT(JavaScriptAndroidMessagingTransport transport) => '''
class HostMessenger {
    constructor(name) {
        this.channelName = name;
        this.pendingMessages = [];
    }

    getPendingMessages() {
        return this.pendingMessages.map(m => ({id: m.id, message: m.message}));
    }

    removeMessageById(id) {
        this.pendingMessages = this.pendingMessages.filter(m => m.id !== id);
    }

    rejectAll(error) {
        const pending = this.pendingMessages;
        this.pendingMessages = [];
        pending.forEach(m => m.reject(error));
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
            // One counter shared by all messengers so ids are never reused when a channel is re-added.
            const nextId = globalThis.JavaScriptAndroid.nextMessageId++;
            this.pendingMessages.push({
                id: nextId,
                message,
                resolve,
                reject
            });
            if (globalThis.JavaScriptAndroid.usePort) {
                globalThis.JavaScriptAndroid.sendToHost(JSON.stringify({ channelName: this.channelName, id: nextId, message }));
            } else if (globalThis.JavaScriptAndroid.useConsoleMessagingHack) {
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
  nextMessageId: 0,
  /// Using console.warn because it may be the least used console method.
  useConsoleMessagingHack: ${transport == JavaScriptAndroidMessagingTransport.consoleMessaging} ? console.warn : false,
  usePort: ${transport == JavaScriptAndroidMessagingTransport.messagePort},
  port: null,
  portQueue: [],
  /// Posts a string to the host, queueing it until the message port is ready.
  sendToHost: function(raw) {
    const self = globalThis.JavaScriptAndroid;
    if (self.port) {
      self.port.postMessage(raw);
    } else {
      self.portQueue.push(raw);
    }
  },
  /// Handles `{channelName, id, ok, message | error}` replies from the host.
  onHostMessage: function(raw) {
    try {
      const reply = JSON.parse(raw);
      const channel = globalThis.JavaScriptAndroid.HostMessengerRegisteredChannels[reply.channelName];
      if (!channel) return;
      if (reply.ok) {
        channel.resolveById(reply.id, reply.message);
      } else {
        channel.rejectById(reply.id, new Error(reply.error));
      }
    } catch (e) {
      console.error('Failed to handle a message from the host', e);
    }
  },
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

if (globalThis.JavaScriptAndroid.usePort) {
  android.getNamedPort("javascript_android_host").then(function (port) {
    const self = globalThis.JavaScriptAndroid;
    port.onmessage = function (e) { self.onHostMessage(e.data); };
    self.port = port;
    // Flush messages posted before the port was ready.
    const queued = self.portQueue;
    self.portQueue = [];
    queued.forEach(function (raw) { port.postMessage(raw); });
  }, function (e) {
    console.error('Failed to open the host message port', e);
  });
}
void 0;
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
