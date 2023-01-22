import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:firebase_ml_custom/firebase_ml_custom.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:camera/camera.dart';

late List<CameraDescription> _cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  _cameras = await availableCameras();
  runApp(const CameraApp());
}


class CameraApp extends StatefulWidget {

  const CameraApp({Key? key}) : super(key: key);

  @override
  State<CameraApp> createState() => _CameraAppState();
}

class _CameraAppState extends State<CameraApp> {
  late CameraController controller;

  @override
  void initState() {
    super.initState();
    controller = CameraController(_cameras[0], ResolutionPreset.max);
    controller.initialize().then((_) {
      if (!mounted) {
        return;
      }
      setState(() {});
    }).catchError((Object e) {
      if (e is CameraException) {
        switch (e.code) {
          case 'CameraAccessDenied':

            break;
          default:

            break;
        }
      }
    });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!controller.value.isInitialized) {
      return Container();
    }
    return MaterialApp(
    );
  }
}
class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  File? _image;
  List<Map<dynamic, dynamic>>? _labels;


  Future<String> _loaded = loadModel();


  Future<void> getImageLabels() async {
    try {
      final pickedFile =
          await ImagePicker().getImage(source: ImageSource.gallery);
      final image = File(pickedFile!.path);
      if (image == null) {
        return;
      }
      TODO TFLite plugin is broken, see https://github.com/shaqian/flutter_tflite/issues/139#issuecomment-836596852
      var labels = List<Map>.from(await Tflite.runModelOnImage(
        path: image.path,
        imageStd: 127.5,
      ));
      var labels = List<Map>.from([]);
      setState(() {
        _labels = labels;
        _image = image;
      });
    } catch (exception) {
      print("Failed on getting your image and it's labels: $exception");
      print('Continuing with the program...');
      rethrow;
    }
  }

 
  static Future<String> loadModel() async {
    final modelFile = await loadModelFromFirebase();
    return loadTFLiteModel(modelFile);
  }


  static Future<File> loadModelFromFirebase() async {
    try {

      final model = FirebaseCustomRemoteModel('action5');


      final conditions = FirebaseModelDownloadConditions(
          androidRequireWifi: true, iosAllowCellularAccess: false);

      final modelManager = FirebaseModelManager.instance;


      await modelManager.download(model, conditions);
      assert(await modelManager.isModelDownloaded(model) == true);

      var modelFile = await modelManager.getLatestModelFile(model);
      assert(modelFile != null);
      return modelFile;
    } catch (exception) {
      print('Failed on loading your model from Firebase: $exception');
      print('The program will not be resumed');
      rethrow;
    }
  }

  static Future<String> loadTFLiteModel(File modelFile) async {
    try {
      
      final appDirectory = await getApplicationDocumentsDirectory();
      final labelsData =
          await rootBundle.load('assets/labels_mobilenet_v1_224.txt');
      final labelsFile =
          await File('${appDirectory.path}/_labels_mobilenet_v1_224.txt')
              .writeAsBytes(labelsData.buffer.asUint8List(
                  labelsData.offsetInBytes, labelsData.lengthInBytes));
      assert(await Tflite.loadModel(
            model: modelFile.path,
            labels: labelsFile.path,
            isAsset: false,
          ) ==
          'success');
      return 'Model is loaded';
    } catch (exception) {
      print(
          'Failed on loading your model to the TFLite interpreter: $exception');
      print('The program will not be resumed');
      rethrow;
    }
  }


  Widget readyScreen() {
    return MaterialApp(home:Scaffold(
      appBar: AppBar(
        title: const Text('Vocalize'),
      ),
      body: Column(
        children: [
          if (_image != null)
            Image.file(_image!)
          else
          Column(
            children: _labels != null
                ? _labels!.map((label) {
                  var out=label["label"]
                  }).toList()
                : [],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: getImageLabels,
        child: const Icon(Icons.add),
      ),
    ));
  }
  Widget errorScreen() {
    return  MaterialApp(home: Scaffold(
      body: Center(
        child: Text('Error loading model. Please check the logs.'),
      ),
    ));
  }

  Widget loadingScreen() {
    return MaterialApp(home:Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const <Widget>[
            Padding(
              padding: EdgeInsets.only(bottom: 20),
              child: CircularProgressIndicator(),
            ),
            Text('Please make sure that you are using wifi.'),
          ],
        ),
      ),
    ));
  }
  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle(
      style: Theme.of(context).textTheme.headline2!,
      textAlign: TextAlign.center,
      child: FutureBuilder<String>(
        future: _loaded, 
        builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
          if (snapshot.hasData) {
            return readyScreen();
          } else if (snapshot.hasError) {
            return errorScreen();
          } else {
            return loadingScreen();
          }
        },
      ),
    );
  }
}

class TextToSpeech extends StatelessWidget {
  final FlutterTts flutterTts = FlutterTts();
  final TextEditingController textEditingController = TextEditingController();
  final GoogleTranslator translator = GoogleTranslator();

  translate(String text,String language) async{
    var translation = await translator
      .translate(text, from: 'en', to: language);
      speak(translation,language) ;
  }
  speak(String text,String language) async {
    await flutterTts.setLanguage(language);
    await flutterTts.setPitch(1);
    await flutterTts.speak(text);
  }
  @override
  Widget build(BuildContext context) {
    return  
       Padding(
            padding: const EdgeInsets.all(25),
            child: Column(
            
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Container(height: 550,),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children:[ElevatedButton(
                  onPressed: () => translate(out,"eng"),
                  child: Text("English Speech")),
                  ElevatedButton(
                  onPressed: () => translate(out,"hin"),
                  child: Text("Hindi Speech")),]
              
              ),
                 Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children:[
                  ElevatedButton(
                  onPressed: () => translate(out,"tam"),
                  child: Text("Tamil Speech")),
                  ElevatedButton(
                  onPressed: () => translate(out,"ml"),
                  child: Text("Malayalam Speech")),]
              
              ),
            ]),
                       
       )
      
    ;
  }
}
