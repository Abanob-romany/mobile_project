import 'check.dart';

const double impactLimit = 20.0;
const double rotateLimit = 5.0;
const double speedLimit = 10.0;

class Logic {
  static bool checkAccident(double acc, double oldAcc, double rotate, double oldRotate, double speed, double oldSpeed) {
    double changeAcc = (acc - oldAcc).abs();
    double changeRotate = (rotate - oldRotate).abs();
    double dropSpeed = oldSpeed - speed;

    bool hardImpact = changeAcc > impactLimit;
    bool fastRotate = changeRotate > rotateLimit;
    bool suddenStop = dropSpeed > speedLimit;

    if (hardImpact && fastRotate && suddenStop) {
      bool fake = Check.isFake(changeAcc, changeRotate, dropSpeed);
      if (!fake) {
        return true;
      }
    }
    return false;
  }
}
