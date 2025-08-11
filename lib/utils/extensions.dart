import 'package:vector_math/vector_math_64.dart' as vm;

extension Matrix3ToQuaternionMap on vm.Matrix3 {
  Map<String, double> toQuaternionMap() {
    final quat = vm.Quaternion.fromRotation(this);
    return {
      'x': quat.x,
      'y': quat.y,
      'z': quat.z,
      'w': quat.w,
    };
  }
}

extension Vector4ToQuaternionMap on vm.Vector4 {
  Map<String, double> toQuaternionMap() {
    return {
      'x': this.x,
      'y': this.y,
      'z': this.z,
      'w': this.w,
    };
  }
}

extension Matrix4ToNestedList on vm.Matrix4 {
  List<List<double>> toNestedList() {
    return [
      [this.entry(0, 0), this.entry(0, 1), this.entry(0, 2), this.entry(0, 3)],
      [this.entry(1, 0), this.entry(1, 1), this.entry(1, 2), this.entry(1, 3)],
      [this.entry(2, 0), this.entry(2, 1), this.entry(2, 2), this.entry(2, 3)],
      [this.entry(3, 0), this.entry(3, 1), this.entry(3, 2), this.entry(3, 3)],
    ];
  }
}