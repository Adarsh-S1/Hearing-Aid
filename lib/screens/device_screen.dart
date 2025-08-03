import 'dart:async';
import 'dart:math';
//import 'dart:math';
import 'package:drop_down_list/model/selected_list_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:listening_aid/screens/apptextfield.dart';
import 'package:listening_aid/screens/leaky_bucket.dart';
import '../widgets/service_tile.dart';
import '../widgets/characteristic_tile.dart';
import '../widgets/descriptor_tile.dart';
import '../utils/snackbar.dart';
import '../utils/extra.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'dart:convert';
import 'package:drop_down_list/drop_down_list.dart';

class DeviceScreen extends StatefulWidget {
  final BluetoothDevice device;

  const DeviceScreen({super.key, required this.device});

  @override
  State<DeviceScreen> createState() => _DeviceScreenState();
}

class _DeviceScreenState extends State<DeviceScreen> {
  int? _rssi;
  int _mtuSize = 23; //HAS TO DYNAMICALLY CHANGE ACCORDING TO DEVICE
  BluetoothConnectionState _connectionState =
      BluetoothConnectionState.disconnected;
  List<BluetoothService> _services = [];
  bool _isDiscoveringServices = false;
  bool _isConnecting = false;
  bool _isDisconnecting = false;

  late StreamSubscription<BluetoothConnectionState>
  _connectionStateSubscription;
  late StreamSubscription<bool> _isConnectingSubscription;
  late StreamSubscription<bool> _isDisconnectingSubscription;
  late StreamSubscription<int> _mtuSubscription;

  // SPEECH RECOGNITION
  final SpeechToText _speechToText = SpeechToText();
  bool _speechEnabled = false;
  String _lastWords = '';
  List<SelectedListItem<LocaleName>> _listOfLanguages = [];
  LocaleName selectedlang = LocaleName("en-US", "English");
  //final TextEditingController _textEditingController = TextEditingController();

  // UUIDs
  static const String serviceUuid = "4fafc201-1fb5-459e-8fcc-c5c9c331914b";
  // static const String characteristicUuid =
  //     "beb5483e-36e1-4688-b7f5-ea07361b26a8";
  late BluetoothCharacteristic characteristic;
  LeakyBucket leakyBucket = LeakyBucket(capacity: 40, leakRatePerSecond: 25);
  //bool isstillListening = false;
  String _currentLocaleId = '';

  @override
  void initState() {
    super.initState();

    _connectionStateSubscription = widget.device.connectionState.listen((
      state,
    ) async {
      _connectionState = state;
      if (state == BluetoothConnectionState.connected) {
        _services = []; // must rediscover services
      }
      if (state == BluetoothConnectionState.connected && _rssi == null) {
        _rssi = await widget.device.readRssi();
      }
      if (mounted) {
        setState(() {});
      }
    });

    _mtuSubscription = widget.device.mtu.listen((value) {
      _mtuSize = value;
      if (mounted) {
        setState(() {});
      }
    });

    _isConnectingSubscription = widget.device.isConnecting.listen((value) {
      _isConnecting = value;
      if (mounted) {
        setState(() {});
      }
    });

    _isDisconnectingSubscription = widget.device.isDisconnecting.listen((
      value,
    ) {
      _isDisconnecting = value;
      if (mounted) {
        setState(() {});
      }
    });

    _initSpeech();
  }

  //===================================================================================================================
  // ALL SPEECH FUNCTION
  void _initSpeech() async {
    _speechEnabled = await _speechToText.initialize();

    var systemLocale = await _speechToText.systemLocale();
    _currentLocaleId = systemLocale?.localeId ?? '';

    final locales = await _speechToText.locales(); // Returns List<LocaleName>
    for (final locale in locales) {
      _listOfLanguages.add(
        SelectedListItem(data: LocaleName(locale.localeId, locale.name)),
      );
    }
    setState(() {});
  }

  void _startListening() async {
    print("Entered _start");
    await _speechToText.listen(
      onResult: _onSpeechResult,
      //listenFor: Duration(minutes: 25),
      //pauseFor: Duration(minutes: 5),
      localeId: _currentLocaleId,
    );
    setState(() {});

    //to prevent interuption
  }

  void _stopListening() async {
    print("This is stop listening");
    await _speechToText.stop();
    setState(() {});
  }

  int _longestCommonPrefix(String a, String b) {
    int minLength = min(a.length, b.length);
    for (int i = 0; i < minLength; i++) {
      if (a[i] != b[i]) return i;
    }
    return minLength;
  }

  String _getNewText(String previousText, String newText) {
    int commonPrefixLength = _longestCommonPrefix(previousText, newText);
    return newText.substring(commonPrefixLength);
  }

  //int _initialsendpointer = 0;
  String _currentdeletetext = '';

  void _onSpeechResult(SpeechRecognitionResult result) async {
    print("====================================================\n");
    print(result.recognizedWords);
    print("====================================================\n");
    setState(() {
      _lastWords = result.recognizedWords;
    });
    try {
      final maxChunkSize = max(_mtuSize - 3, 20);
      if (leakyBucket.allowRequest()) {
        String chunk = _getNewText(_currentdeletetext, result.recognizedWords);
        if (chunk.length > maxChunkSize) {
          for (int i = 0; i < chunk.length; i += maxChunkSize) {
            String chunkData = chunk.substring(
              i,
              i + maxChunkSize > chunk.length ? chunk.length : i + maxChunkSize,
            );
            await characteristic.write(utf8.encode(chunkData));
          }
        } else {
          await characteristic.write(utf8.encode(chunk));
        }
        _currentdeletetext = result.recognizedWords;
        debugPrint(chunk);
        chunk = "";
        await Future.delayed(const Duration(milliseconds: 500));
      } else {
        debugPrint("leakyBucket.allowRequest() == false");
        Snackbar.show(ABC.c, "Speak slowly", success: false);
      }
    } catch (e) {
      Snackbar.show(ABC.c, "Send error: $e", success: false);
    }
  }

  //     // if (result.recognizedWords.length % maxChunkSize == 0) {
  //     //   print("================================================");
  //     //   print(result.recognizedWords);
  //     //   print("================================================");
  //     //   String chunk = result.recognizedWords.substring(
  //     //     _initialsendpointer,
  //     //     min(
  //     //       _initialsendpointer + maxChunkSize,
  //     //       result.recognizedWords.length,
  //     //     ),
  //     //   );
  //     //   _initialsendpointer += min(
  //     //     _initialsendpointer + maxChunkSize,
  //     //     result.recognizedWords.length,
  //     //   );
  //     //   await characteristic.write(utf8.encode(chunk));
  //     // }
  //     // print("================================================");
  //     // print(_sendtext);
  //     // print("================================================");

  //     // for (var i = 0; i < _sendtext.length; i += maxChunkSize) {
  //     //   String chunk = _sendtext.substring(
  //     //     i,
  //     //     min(i + maxChunkSize, _sendtext.length),
  //     //   );
  //     //   await characteristic.write(utf8.encode(chunk));
  //     //   await Future.delayed(const Duration(milliseconds: 50));
  //     //}
  //   } catch (e) {
  //     if (mounted) Snackbar.show(ABC.c, "Send error: $e", success: false);
  //   }
  // }

  //==================================================================================================================
  @override
  void dispose() {
    _connectionStateSubscription.cancel();
    _mtuSubscription.cancel();
    _isConnectingSubscription.cancel();
    _isDisconnectingSubscription.cancel();
    super.dispose();
  }

  bool get isConnected {
    return _connectionState == BluetoothConnectionState.connected;
  }

  Future onConnectPressed() async {
    try {
      await widget.device.connectAndUpdateStream();
      Snackbar.show(ABC.c, "Connect: Success", success: true);
    } catch (e, backtrace) {
      if (e is FlutterBluePlusException &&
          e.code == FbpErrorCode.connectionCanceled.index) {
        // ignore connections canceled by the user
      } else {
        Snackbar.show(
          ABC.c,
          prettyException("Connect Error:", e),
          success: false,
        );
        print(e);
        print("backtrace: $backtrace");
      }
    }
  }

  Future onCancelPressed() async {
    try {
      await widget.device.disconnectAndUpdateStream(queue: false);
      Snackbar.show(ABC.c, "Cancel: Success", success: true);
    } catch (e, backtrace) {
      Snackbar.show(ABC.c, prettyException("Cancel Error:", e), success: false);
      print("$e");
      print("backtrace: $backtrace");
    }
  }

  Future onDisconnectPressed() async {
    try {
      await widget.device.disconnectAndUpdateStream();
      Snackbar.show(ABC.c, "Disconnect: Success", success: true);
    } catch (e, backtrace) {
      Snackbar.show(
        ABC.c,
        prettyException("Disconnect Error:", e),
        success: false,
      );
      print("$e backtrace: $backtrace");
    }
  }

  Future onDiscoverServicesPressed() async {
    if (mounted) {
      setState(() {
        _isDiscoveringServices = true;
      });
    }
    try {
      _services = await widget.device.discoverServices();
      Snackbar.show(ABC.c, "Discover Services: Success", success: true);
    } catch (e, backtrace) {
      Snackbar.show(
        ABC.c,
        prettyException("Discover Services Error:", e),
        success: false,
      );
      print(e);
      print("backtrace: $backtrace");
    }
    if (mounted) {
      setState(() {
        _isDiscoveringServices = false;
      });
    }
  }

  Future onRequestMtuPressed() async {
    try {
      await widget.device.requestMtu(223, predelay: 0);
      Snackbar.show(ABC.c, "Request Mtu: Success", success: true);
    } catch (e, backtrace) {
      Snackbar.show(
        ABC.c,
        prettyException("Change Mtu Error:", e),
        success: false,
      );
      print(e);
      print("backtrace: $backtrace");
    }
  }

  List<Widget> _buildServiceTiles(BuildContext context, BluetoothDevice d) {
    return _services.map((s) {
      if (s.uuid.toString() == serviceUuid) {
        characteristic = s.characteristics[0];
        return ServiceTile(
          service: s,
          characteristicTiles:
              s.characteristics
                  .map((c) => _buildCharacteristicTile(c))
                  .toList(),
        );
      } else {
        return SizedBox();
      }
    }).toList();
  }

  CharacteristicTile _buildCharacteristicTile(BluetoothCharacteristic c) {
    return CharacteristicTile(
      characteristic: c,
      descriptorTiles:
          c.descriptors.map((d) => DescriptorTile(descriptor: d)).toList(),
    );
  }

  Widget buildSpinner(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(14.0),
      child: AspectRatio(
        aspectRatio: 1.0,
        child: CircularProgressIndicator(
          backgroundColor: Colors.black12,
          color: Colors.black26,
        ),
      ),
    );
  }

  Widget buildRemoteId(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text('${widget.device.remoteId}'),
    );
  }

  Widget buildRssiTile(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        isConnected
            ? const Icon(Icons.bluetooth_connected)
            : const Icon(Icons.bluetooth_disabled),
        Text(
          ((isConnected && _rssi != null) ? '${_rssi!} dBm' : ''),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget buildGetServices(BuildContext context) {
    return IndexedStack(
      index: (_isDiscoveringServices) ? 1 : 0,
      children: <Widget>[
        TextButton(
          child: const Text("Get Services"),
          onPressed: onDiscoverServicesPressed,
        ),
        const IconButton(
          icon: SizedBox(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation(Colors.grey),
            ),
            width: 18.0,
            height: 18.0,
          ),
          onPressed: null,
        ),
      ],
    );
  }

  Widget buildMtuTile(BuildContext context) {
    return ListTile(
      title: const Text('MTU Size'),
      subtitle: Text('$_mtuSize bytes'),
      trailing: IconButton(
        icon: const Icon(Icons.edit),
        onPressed: onRequestMtuPressed,
      ),
    );
  }

  Widget buildConnectButton(BuildContext context) {
    return Row(
      children: [
        if (_isConnecting || _isDisconnecting) buildSpinner(context),
        TextButton(
          onPressed:
              _isConnecting
                  ? onCancelPressed
                  : (isConnected ? onDisconnectPressed : onConnectPressed),
          child: Text(
            _isConnecting ? "CANCEL" : (isConnected ? "DISCONNECT" : "CONNECT"),
            style: Theme.of(
              context,
            ).primaryTextTheme.labelLarge?.copyWith(color: Colors.black),
          ),
        ),
      ],
    );
  }

  void mydropdown() {
    DropDownState<LocaleName>(
      dropDown: DropDown<LocaleName>(
        isDismissible: true,
        maxSelectedItems: 1,
        submitButtonText: 'Save',
        data: _listOfLanguages,
        onSelected: (selectedItems) {
          selectedlang = selectedItems.first.data;
        },
        listItemBuilder: (index, dataItem) {
          return Text(dataItem.data.name);
        },
      ),
    ).showModal(context);
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
      key: Snackbar.snackBarKeyC,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.device.platformName),
          actions: [buildConnectButton(context)],
        ),
        body: SingleChildScrollView(
          child: Column(
            children: <Widget>[
              //buildRemoteId(context),
              ListTile(
                leading: buildRssiTile(context),
                title: Text(
                  'Device is ${_connectionState.toString().split('.')[1]}.',
                ),
                trailing: buildGetServices(context),
              ),
              buildMtuTile(context),
              ..._buildServiceTiles(context, widget.device),
              // AppTextField(
              //   isReadOnly: true,
              //   textEditingController: _textEditingController,
              //   title: "",
              //   hint: "Language",
              //   onTextFieldTap: () => mydropdown(),
              // ),
              Container(
                width: 300,
                height: 500,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black),
                  borderRadius: BorderRadius.circular(30),
                ),
                padding: EdgeInsets.all(16),
                child: Text(
                  _speechToText.isListening
                      ? _lastWords
                      : _speechEnabled
                      ? 'Tap the microphone to start listening...'
                      : 'Speech not available',
                ),
              ),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed:
              // If not yet listening for speech start, otherwise stop
              _speechToText.isNotListening ? _startListening : _stopListening,
          tooltip: 'Listen',
          child: Icon(_speechToText.isNotListening ? Icons.mic_off : Icons.mic),
        ),
      ),
    );
  }
}
