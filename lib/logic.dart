const double impactLimit = 22.0;
const double rotateLimit = 5.0;
const double speedDropLimit = 15.0;

class Logic {
  static String verifyCrash(
    double maxAcc,
    double maxRotate,
    double speedDrop,
    double endAcc,
    double endRotate,
  ) {
    bool cond1 = maxAcc > impactLimit && maxRotate > rotateLimit;
    bool cond2 = maxAcc > impactLimit && speedDrop > speedDropLimit;

    if (cond1 || cond2) {
      return "CONFIRMED";
    }

    if (maxAcc <= impactLimit) {
      return "False Alarm: Low Impact";
    }

    return "False Alarm: Insufficient Rotation or Speed Drop";
  }

  static bool checkAccident(double acc, double rotate) {
    return acc > 22.0 || (acc > 18.0 && rotate > 5.0);
  }
}
