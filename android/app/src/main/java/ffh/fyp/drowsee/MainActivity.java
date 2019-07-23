package ffh.fyp.drowsee;

import android.content.res.AssetFileDescriptor;
import android.os.Bundle;
import android.renderscript.RenderScript;
import java.io.FileInputStream;
import java.io.IOException;
import java.nio.ByteBuffer;
import java.nio.channels.FileChannel;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import io.flutter.app.FlutterActivity;
import io.flutter.plugins.GeneratedPluginRegistrant;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;

public class MainActivity extends FlutterActivity {

  private static final String CHANNEL = "ffh.fyp/tensorflow";
  private static CNNDetector detector;
  private static boolean modelLoaded = false;
  private RenderScript rs;

  @Override
  protected void onCreate(Bundle savedInstanceState) {
    super.onCreate(savedInstanceState);
    GeneratedPluginRegistrant.registerWith(this);
    rs = RenderScript.create(this);
    new MethodChannel(getFlutterView(), CHANNEL).setMethodCallHandler(new MethodCallHandler() {
      @Override
      public void onMethodCall(MethodCall call, Result result) {
        if (call.method.equals("loadModel")) {
          String modelPath = call.argument("model_path");
          Map metaData = call.argument("meta_data");
          loadModel(modelPath, metaData, result);
        } else if (call.method.equals("detectObject")) {
          HashMap image = call.arguments();
          detectObject(image, result);
        }

      }
    });
  }

  protected void loadModel(final String modelPath, final Map metaData, final Result result) {
    new Thread(new Runnable() {
      public void run() {
        try {
          String modelPathKey = getFlutterView().getLookupKeyForAsset(modelPath);
          ByteBuffer modelData = loadModelFile(getApplicationContext().getAssets().openFd(modelPathKey));
          detector = new CNNDetector(rs, modelData, metaData);
          modelLoaded = true;
          result.success("Model Loaded Sucessfully");
        } catch (Exception e) {
          e.printStackTrace();
          result.error("Model failed to loaded", e.getMessage(), null);
        }
      }
    }).start();
  }

  public ByteBuffer loadModelFile(AssetFileDescriptor fileDescriptor) throws IOException {
    FileInputStream inputStream = new FileInputStream(fileDescriptor.getFileDescriptor());
    FileChannel fileChannel = inputStream.getChannel();
    long startOffset = fileDescriptor.getStartOffset();
    long declaredLength = fileDescriptor.getDeclaredLength();
    return fileChannel.map(FileChannel.MapMode.READ_ONLY, startOffset, declaredLength);
  }

  public void detectObject(final HashMap image, final Result result) {
    new Thread(new Runnable() {
      public void run() {
        if (!modelLoaded)
          result.error("Model is not loaded", null, null);

        try {
          List<Map<String, Object>> prediction = detector.detect(image);
          result.success(prediction);
        } catch (Exception e) {
          e.printStackTrace();
          result.error("Running model failed", e.getMessage(), null);
        }
      }
    }).start();
  }
}