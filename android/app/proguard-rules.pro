# ONNX Runtime is accessed from JNI and looks up these classes by name.
# Without this, R8 removes/renames TensorInfo and inference aborts with
# "Pending exception java.lang.ClassNotFoundException: ai.onnxruntime.TensorInfo".
-keep class ai.onnxruntime.** { *; }
-keepclassmembers class ai.onnxruntime.** { *; }
-dontwarn ai.onnxruntime.**
