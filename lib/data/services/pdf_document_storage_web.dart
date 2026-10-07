import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

const _databaseName = 'readwise_local_library';
const _storeName = 'pdf_documents';

Future<web.IDBDatabase>? _databaseFuture;

Future<web.IDBDatabase> _database() => _databaseFuture ??= _openDatabase();

Future<web.IDBDatabase> _openDatabase() async {
  final request = web.window.indexedDB.open(_databaseName, 1);
  request.onupgradeneeded = ((web.IDBVersionChangeEvent event) {
    (request.result as web.IDBDatabase).createObjectStore(_storeName);
  }).toJS;
  return (await _waitForRequest(request)) as web.IDBDatabase;
}

Future<void> saveBrowserPdf(String key, Uint8List bytes) async {
  final database = await _database();
  final transaction = database.transaction(_storeName.toJS, 'readwrite');
  final completed = _waitForTransaction(transaction);
  await _waitForRequest(
    transaction.objectStore(_storeName).put(bytes.toJS, key.toJS),
  );
  await completed;
}

Future<Uint8List?> loadBrowserPdf(String key) async {
  final database = await _database();
  final transaction = database.transaction(_storeName.toJS, 'readonly');
  final completed = _waitForTransaction(transaction);
  final result = await _waitForRequest(
    transaction.objectStore(_storeName).get(key.toJS),
  );
  await completed;
  if (result == null) return null;
  return (result as JSUint8Array).toDart;
}

Future<void> deleteBrowserPdf(String key) async {
  final database = await _database();
  final transaction = database.transaction(_storeName.toJS, 'readwrite');
  final completed = _waitForTransaction(transaction);
  await _waitForRequest(transaction.objectStore(_storeName).delete(key.toJS));
  await completed;
}

Future<JSAny?> _waitForRequest(web.IDBRequest request) {
  final completer = Completer<JSAny?>();
  request.onsuccess = ((web.Event event) {
    if (!completer.isCompleted) completer.complete(request.result);
  }).toJS;
  request.onerror = ((web.Event event) {
    if (!completer.isCompleted) {
      completer.completeError(
        request.error ?? StateError('Browser storage request failed.'),
      );
    }
  }).toJS;
  return completer.future;
}

Future<void> _waitForTransaction(web.IDBTransaction transaction) {
  final completer = Completer<void>();
  transaction.oncomplete = ((web.Event event) {
    if (!completer.isCompleted) completer.complete();
  }).toJS;
  transaction.onerror = ((web.Event event) {
    if (!completer.isCompleted) {
      completer.completeError(
        transaction.error ?? StateError('Browser storage transaction failed.'),
      );
    }
  }).toJS;
  transaction.onabort = ((web.Event event) {
    if (!completer.isCompleted) {
      completer.completeError(
        transaction.error ??
            StateError('Browser storage transaction was cancelled.'),
      );
    }
  }).toJS;
  return completer.future;
}
