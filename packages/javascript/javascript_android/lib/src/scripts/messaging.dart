const String MESSAGING_SCRIPT = r'''
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
''';