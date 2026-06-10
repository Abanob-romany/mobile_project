const double impactLimit = 22.0;
const double rotateLimit = 5.0;
const double speedDropLimit = 15.0;

class Logic {
  static String verifyCrash(
    double maxAcc,
    double maxRotate,
    double speedDrop,
  ) {
    bool cond1 = maxAcc > impactLimit && maxRotate > rotateLimit;
    bool cond2 = maxAcc > impactLimit && speedDrop > speedDropLimit;

    if (cond1 || cond2) {
      return "confirmed";
    }

    if (maxAcc <= impactLimit) {
      return "false alarm: low impact";
    }

    return "false alarm";
  }

  static bool checkAccident(double acc, double rotate) {
    return acc > impactLimit || (acc > 18.0 && rotate > rotateLimit);
  }
}
