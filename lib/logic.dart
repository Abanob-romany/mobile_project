const double impactLimit = 25.0;
const double rotateLimit = 6.0;
const double speedDropLimit = 15.0;

class Logic {
  static String verifyCrash(
    double maxAcc,
    double maxRotate,
    double speedDrop,
    double endAcc,
    double endRotate,
  ) {
    bool bigHit = maxAcc >= impactLimit;
    bool bigSpin = maxRotate >= rotateLimit;
    bool bigDrop = speedDrop >= speedDropLimit;

    bool noMovement = endAcc < 2.0 && endRotate < 1.0;
    bool continuedMovement = endAcc >= 2.0 || endRotate >= 1.0;

    if (continuedMovement) {
      return "Movement Continued Normally";
    }

    if (bigHit && bigSpin && bigDrop) {
      return "CONFIRMED";
    }

    if (bigHit && bigSpin && noMovement) {
      return "CONFIRMED";
    }
    if (bigHit && !bigSpin) {
      return "False Alarm: Impact Only";
    }

    if (!bigHit && bigSpin) {
      return "False Alarm: Rotation Only";
    }

    return "No Real Accident Detected";
  }

  static bool checkAccident(double acc, double rotate, double speedDrop) {
    return acc > 20.0 || rotate > 6.0;
  }
}
