import 'dart:ffi';
import 'dart:isolate';
import 'package:ffi/ffi.dart';
import 'package:async/async.dart';
import 'package:flutter/material.dart';
import 'package:win32/win32.dart';

ReceivePort mainReceivePort = ReceivePort();
SendPort? mainSendPort;
SendPort? hookSendPort;
void main() async {
  await Isolate.spawn(hookIsolate, mainReceivePort.sendPort);
  runApp(const MyApp());
}

const int cINPUT = 2;
final pInputs = calloc<INPUT>(cINPUT);
int lowLevelKeyboardProc(int nCode, int wParam, int lParam) {
  Pointer<KBDLLHOOKSTRUCT> ks = Pointer.fromAddress(lParam);
  if (ks.ref.flags == 128 || ks.ref.flags == 129) {
    switch(ks.ref.vkCode) {
      case 0x30 || 0x60:
        ZeroMemory(pInputs, sizeOf<INPUT>() * cINPUT);
        mainSendPort?.send('${ks.ref.flags}');
        pInputs[0].type = INPUT_KEYBOARD;
        pInputs[0].ki.wVk = VK_LWIN;
        pInputs[1].type = INPUT_KEYBOARD;
        pInputs[1].ki.wVk = VK_LWIN;
        pInputs[1].ki.dwFlags = KEYEVENTF_KEYUP;
        // pInputs[2].type = INPUT_KEYBOARD;
        // pInputs[2].ki.wVk = VK_HOME;
        // pInputs[3].type = INPUT_KEYBOARD;
        // pInputs[3].ki.wVk = VK_CONTROL;
        // pInputs[3].ki.dwFlags = KEYEVENTF_KEYUP;
        // pInputs[4].type = INPUT_KEYBOARD;
        // pInputs[4].ki.wVk = VK_SHIFT;
        // pInputs[4].ki.dwFlags = KEYEVENTF_KEYUP;
        // pInputs[5].type = INPUT_KEYBOARD;
        // pInputs[5].ki.wVk = VK_HOME;
        // pInputs[5].ki.dwFlags = KEYEVENTF_KEYUP;
        if (SendInput(cINPUT, pInputs, sizeOf<INPUT>()) != cINPUT) {
          mainSendPort?.send('error SendInput');
        }
    }
  }

  return CallNextHookEx(0, nCode, wParam, lParam);
}

void hookIsolate(SendPort sendPort){
  final receivePort = ReceivePort();
  mainSendPort = sendPort;
  sendPort.send(receivePort.sendPort);
  SetWindowsHookEx(WH_KEYBOARD_LL, Pointer.fromFunction(lowLevelKeyboardProc, 0), GetModuleHandle(nullptr), 0);
  final msg = calloc<MSG>();
  while (GetMessage(msg, NULL, 0, 0) != 0) {
    TranslateMessage(msg);
    DispatchMessage(msg);
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => MyHomePageState();
}

class MyHomePageState extends State<MyHomePage> {
  String _msg = 'empty';

  void eventLoop() async {
    final events = StreamQueue(mainReceivePort);
    hookSendPort = await events.next;
    await for (final String msg in events.rest) {
        setState(() {
          _msg = msg;
        });
    }
  }

  MyHomePageState() {
    eventLoop();
  }

  void _incrementCounter() {
    setState(() {
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              'You have pushed the button this many times:',
            ),
            Text(
              _msg,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
