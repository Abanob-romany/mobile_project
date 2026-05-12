class Check {
  static bool isFake(double acc, double rotate, double speed) {
    if (acc > 15.0 && speed < 5.0 && rotate < 5.0) return true;
    if (speed > 10.0 && acc < 10.0 && rotate < 2.0) return true;
    if (acc > 10.0 && speed < 2.0 && rotate < 2.0) return true;
    if (acc > 5.0 && speed <= 0) return true;
    return false;
  }
}
