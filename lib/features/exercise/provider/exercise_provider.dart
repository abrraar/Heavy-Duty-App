import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:heavy_duty/core/services/connectivity_service.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/database_helper.dart';
import '../model/exercise_template.dart';
import '../data/exercise_local_repository.dart';
import '../data/exercise_cloud_repository.dart';

class ExerciseProvider with ChangeNotifier {
  ExerciseLocalRepository? _localRepo;
  final ExerciseCloudRepository _cloudRepo = ExerciseCloudRepository();
  final SupabaseClient _supabase = Supabase.instance.client;
  RealtimeChannel? _realtimeChannel;

  List<ExerciseTemplate> _templates = [];
  bool _isLoading = false;
  
  // ELITE CACHE BUSTER: Incremented on refresh to force image re-downloads
  int _imageVersion = DateTime.now().millisecondsSinceEpoch;

  List<ExerciseTemplate> get templates => _templates.map((t) => _applyCacheBuster(t)).toList();
  List<ExerciseTemplate> get defaultTemplates => templates.where((t) => t.isDefault).toList();
  List<ExerciseTemplate> get customTemplates => templates.where((t) => !t.isDefault).toList();
  bool get isLoading => _isLoading;

  ExerciseTemplate _applyCacheBuster(ExerciseTemplate t) {
    if (t.imageUrl == null || !t.imageUrl!.startsWith('http')) return t;
    final separator = t.imageUrl!.contains('?') ? '&' : '?';
    return t.copyWith(imageUrl: '${t.imageUrl}${separator}v=$_imageVersion');
  }

  void initializeForUser(String userId) {
    _localRepo = ExerciseLocalRepository(userId: userId);
    _loadData();
    _setupRealtimeSubscription(userId);
    ConnectivityService().addReconnectListener(_onReconnect);
  }

  void _onReconnect() async {
    debugPrint("ExerciseProvider: Reconnected. Triggering sync...");
    await _syncWithCloud();
  }

  void _setupRealtimeSubscription(String userId) {
    _realtimeChannel?.unsubscribe();
    _realtimeChannel = _supabase.channel('public:exercise_sync:$userId');

    _realtimeChannel!.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'exercise_templates',
      callback: (payload) async {
        debugPrint("Realtime Exercise Template Update: ${payload.eventType}");
        
        final String? recordUserId = payload.newRecord['user_id'] ?? payload.oldRecord['user_id'];
        if (recordUserId != userId) return;

        if (payload.newRecord.isNotEmpty) {
          final template = ExerciseTemplate.fromMap(payload.newRecord);
          
          final localTemplates = await _localRepo!.getAllTemplates();
          final localIdx = localTemplates.indexWhere((t) => t.id == template.id);

          if (localIdx == -1 || localTemplates[localIdx].isSynced == 1) {
            await _localRepo!.insertTemplate(template);
            
            // Seamless update: remove old version if exists and add new one
            _templates.removeWhere((t) => t.id == template.id);
            _templates.add(template);
            _templates.sort((a, b) => a.name.compareTo(b.name));
            notifyListeners();
          }
        } else if (payload.eventType == PostgresChangeEvent.delete) {
          final String? id = payload.oldRecord['id'];
          if (id != null) {
            await _localRepo!.deleteTemplate(id);
            _templates.removeWhere((t) => t.id == id);
            notifyListeners();
          }
        }
      },
    );

    _realtimeChannel!.subscribe((status, [error]) async {
      debugPrint("ExerciseProvider: Realtime Subscription Status: $status");
      if (error != null) {
        debugPrint("ExerciseProvider: Realtime Subscription Error: $error");
      }
      if (status == RealtimeSubscribeStatus.subscribed) {
        debugPrint("ExerciseProvider: Realtime Subscribed/Reconnected. Syncing...");
        await _syncWithCloud();
      }
    });
  }

  Future<void> _loadData() async {
    if (_localRepo == null) return;
    _isLoading = true;
    notifyListeners();

    try {
      _templates = await _localRepo!.getAllTemplates();
      
      await _runSelfHealingCheck();

      // Auto-initialize Mentzer library if missing OR if content is missing
      final defaultCount = _templates.where((t) => t.isDefault).length;
      
      final flyes = _templates.firstWhere(
        (t) => t.name == 'Dumbbell Flyes', 
        orElse: () => ExerciseTemplate(name: 'Empty')
      );
      final hasCitation = flyes.aboutTheMovement != null && flyes.aboutTheMovement!.contains('The Mike Mentzer Way');

      if (defaultCount != 42 || !hasCitation) {
        debugPrint("ExerciseProvider: [UPDATE] Syncing Mentzer library versions...");
        await _initializeDefaults();
        _templates = await _localRepo!.getAllTemplates();
      }
      
      notifyListeners();
      _syncWithCloud();
    } catch (e) {
      debugPrint("ExerciseProvider Error: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// ELITE SELF-HEALING: Detects and fixes broken default exercise mappings (e.g. legacy local assets or wrong extensions)
  Future<void> _runSelfHealingCheck() async {
    final needsHealing = _templates.any((t) => 
      t.isDefault && (
        t.imageUrl == null || 
        !t.imageUrl!.startsWith('http') || // If it doesn't start with http, it's likely a legacy path
        t.imageUrl!.contains('lib/assets/') ||
        t.imageUrl!.endsWith('.jpg') // Ensure we move to .webp
      )
    );

    if (needsHealing) {
      debugPrint("ExerciseProvider: [SELF-HEALING] Detected legacy/broken mappings. Restoring cloud URLs...");
      await _initializeDefaults();
      _templates = await _localRepo!.getAllTemplates();
      notifyListeners();
    }
  }

  Future<void> _syncWithCloud() async {
    if (_localRepo == null) return;
    try {
      // 0. Push Deletions
      final pendingDeletions = await _localRepo!.getPendingDeletions();
      for (var del in pendingDeletions) {
        final id = del['id'] as String;
        try {
          await _cloudRepo.deleteTemplate(id);
          await _localRepo!.removeFromDeletionQueue(id);
        } catch (_) {}
      }

      // 1. PULL and PRUNE from Cloud
      final cloudTemplates = await _cloudRepo.getAllTemplates();
      final cloudIds = cloudTemplates.map((t) => t.id).toSet();
      
      final localTemplates = await _localRepo!.getAllTemplates();
      
      // PRUNE: Delete local custom templates that were previously synced but are now missing from the cloud
      for (var localT in localTemplates) {
        if (!localT.isDefault && localT.isSynced == 1 && !cloudIds.contains(localT.id)) {
          debugPrint("ExerciseProvider: Pruning deleted template: ${localT.name}");
          await _localRepo!.deleteTemplate(localT.id);
        }
      }

      // SYNC: Add or Update templates from the cloud
      for (var t in cloudTemplates) {
        final localT = localTemplates.cast<ExerciseTemplate?>().firstWhere(
          (lt) => lt?.id == t.id, 
          orElse: () => null
        );
        
        if (localT == null || localT.isSynced == 1) {
          await _localRepo!.insertTemplate(t.copyWith(isSynced: 1));
        }
      }

      // 2. PUSH unsynced local templates to Cloud
      final unsynced = await _localRepo!.getUnsyncedTemplates();
      for (var t in unsynced) {
        if (!t.isDefault) {
          await _cloudRepo.insertTemplate(t);
          await _localRepo!.markTemplateSynced(t.id);
        }
      }

      // 3. Final memory refresh
      _templates = await _localRepo!.getAllTemplates();
      notifyListeners();
    } catch (e) {
      debugPrint("Exercise Cloud Sync Error: $e");
    }
  }

  Future<void> _initializeDefaults() async {
    // Purge existing defaults to avoid duplicates and ensure content update
    if (_localRepo != null) {
      final db = await DatabaseHelper.instance.getDatabaseForUser(_localRepo!.userId);
      await db.delete('exercise_templates', where: 'is_default = 1');
    }

    final List<ExerciseTemplate> defaults = [
      _create('Dumbbell Flyes', 'Chest', ExerciseType.isolation, 2, 'With the dumbbells together over the face, lower them to the sides with the elbows pulled back and out to the sides. Lower to a position just below the plane of the torso, and no further, or you might injure the shoulder. Keeping the angle in the elbows consistent throughout the raising of the weight back to the top will stress the pecs, preserve the triceps strength, and reduce strain on the connective tissue in the crook of the elbow. It doesn’t matter if the weights touch at the top, since at that point there is no resistance to fight against anyway.'),
      _create('Incline Presses', 'Chest, Triceps', ExerciseType.compound, 3, 'With a shoulder-width grip, lower the bar to the neck slowly, with the elbows pointed directly out to the side. It is the position of the elbows, more than the hand spacing, that places the greatest stress on the pecs. A common training mistake is to do this exercise with a wide hand spacing with the idea that this stretches the pecs more. Actually, just the opposite is true. A closer hand spacing causes the pecs to stretch and work over a greater range of motion. As proof, witness how little the humerus, or upper arm, which is the insertion point for the pecs, moves in a wide-grip incline or regular bench press. Since the function of the pecs is to bring the upper arm into and across the midline of the torso, the elbows must be held out to the sides so the pecs can perform their function in this exercise.'),
      _create('Straight-Arm Lat Machine Pulldowns', 'Back', ExerciseType.isolation, 2, 'The lat machine bar should be over your head and slightly in front of you so that you’ll have to pull it in towards your body. With a shoulder width grip pull the arms into the thighs, keeping them almost perfectly straight. The idea is to save the strength of your biceps, so it is imperative that you keep the arms straight. Hold the bar at thigh level for a distinct pause before allowing the bar to return slowly to the top overhead position. Watch how sore your abs and serratus get from this great exercise, in addition to the lats.'),
      _create('Palms-Up Pulldowns', 'Back, Biceps', ExerciseType.compound, 3, 'The underhand grip is used because it places the biceps into their strongest position. Most bodybuilders use the palms-down overhead grip that places the biceps in a weak position, limiting the degree to which you can work your back. Another mistake made by bodybuilders is using the wide grip in the pulldown and in chinning movements. Rather than stretch the lats—which is the logic behind using the wide grip—the wide grip actually reduces the stretch, or the range of motion over which the lats contract. Place your upper arm up by your head and feel how much the lats are stretched, and then lower it to the side, as in a wide grip position, and you’ll see that the stretch is greatly diminished. Pull the bar from overhead into the chest around the nipple area, hold for a pause, and return slowly to the top.'),
      _create('Deadlifts', 'Back, Legs, Calf, Abdominals, Shoulder, Triceps', ExerciseType.compound, 5, 'With arms perfectly straight and no jerking or pulling, stand up with the bar until your body is perpendicular to the ground (there is no good reason to arch backwards at the top). Upon reaching the top, pause briefly, and lower under control to the floor in the same manner as you lifted—back flat and head up. Once the barbell is on the floor, reassume the proper form, reset psychologically, take a deep breath, and repeat. This exercise works every muscle on the back side of the body from the calves to the leg biceps, the gluteus, hips, spinal erectors, latissimus, deltoids, arms—really every muscle of the body. (If I could only choose one exercise, it would be deadlifts because, again, it is the most intense, or demanding, and therefore the most productive. It is very stimulating not just for the muscles, but for all of the physiological subsystems, including the cardiovascular system.)'),
      _create('Leg Extensions', 'Legs', ExerciseType.isolation, 2, 'Sit firmly in the seat with your back against the pad, positioned so that your lower legs hang freely, with the back of the knees at the edge of the seat pad. Adjust the machine or your position so that the area just slightly above the front of the ankles makes contact with the pads of the movement arm. While grasping the handles lightly to stabilize yourself, move against the ankle pads evenly and deliberately so that the lower legs move out and up until your knees are locked and you’re in the straight-legged position. Pause for two seconds, and lower under control. This is the perfect exercise for isolating and working the quadriceps on the front of the thighs.'),
      _create('Leg Presses', 'Legs, Calf', ExerciseType.compound, 4, 'To begin this exercise, lie on your back with your feet solidly planted on a foot board. Place your feet shoulder-width or slightly wider than shoulder-width on the foot board and point them out a bit. Your hips should be placed so you feel stable while lowering your legs. Bend your legs (lowering your thighs) until they almost hit the chest, but no lower. Going any lower will hyperextend the lower back muscles and make them prone to injury. This can and will happen with any deviation from strict, controlled exercise performance. For safety, particularly when the weights start really getting heavy, you should fold your arms over your chest to prevent severe compression of the thorax when the weight descends. You can also keep your hands on your upper thighs throughout the movement so that if you lapse, or lose control, you can use the strength of your arms to assist in getting the weight back to the top where you can rack the weight and safely get out of the machine. Not only does this exercise work the quadriceps, or frontal thighs, it works the gracilis and semitendonosis on the inside of the upper leg and the back of the legs (the biceps femoris) as well.'),
      _create('Standing Calf Raises', 'Calf', ExerciseType.isolation, 2, 'Step up under the shoulder pads and place the balls of your feet onto the cross board, which is several inches off the ground. With your body perfectly straight and knees absolutely locked, raise up on the balls of your feet as high as you can go. This is important as it makes for a full, high-intensity contraction, which is necessary for full stimulation of the muscle. As I tell my own personal training clients: “Try to get to the tip top of your toes, like a ballet dancer. I know you can’t, but try it!” Having achieved that position, hold it for two to three seconds, then lower under control.'),
      _create('Sit-Ups', 'Abdominals', ExerciseType.isolation, 2, 'With regular sit-ups, be sure to bend the knees to a 45-degree angle and keep your arms folded across your chest. Performing them in this manner will help remove unnecessary stress from the lower back. Having assumed the proper position, sit up—curl at the waist until your torso is just shy of being perpendicular to the floor, with tension still on the abdominal muscles. When you can do more than 20 reps with your body weight, hold a barbell plate in your folded arms (at the chest) so that you’re only able to do 10 to 12 reps. Stay with that new weight until you can do 20. Unlike the other exercises, where more weight can be handled, increase the weight by only five pounds when the upper limit of the prescribed rep range has been reached. Increasing the weight by 10 percent will be impossible without special equipment—or until you’re handling 50 pounds or more in this exercise'),
      _create('Dumbbell Lateral Raises', 'Shoulder', ExerciseType.isolation, 2, 'While holding a dumbbell in each hand, rest the bells to the sides of your thighs, palms facing your thighs. With a slight bend in the elbows, raise them from that position until your arms are parallel to the ground. Don’t raise them to the front, but laterally, directly up from the side of the body. This is the only delt exercise for which I might recommend a slightly looser style of performance than that described for most exercises. If you don’t use a slight thrust in the beginning of this movement just to get the weight started, you won’t be able to employ a weight heavy enough to provide the necessary resistance in the top, or contracted, position of the exercise. Do not, however, use a weight that requires a ridiculously sloppy style. With only a very slight jerk keep the weight moving with the work of the muscles and hold it at shoulder level for a distinct pause. If you cannot hold it there, remember, you used momentum instead of muscle to perform the work. From the top, lower slowly, and feel the weight all the way back to the starting position. Negatives can be employed here occasionally, by curling the weight to the shoulder and thrusting it to the sides before lowering under control.'),
      _create('Bent-Over Dumbbell Laterals', 'Shoulder', ExerciseType.isolation, 2, 'While bending over at the waist with a slight bend in the knees (with the torso parallel to the floor), raise the dumbbells until the arms move as far above the torso as possible, pause, and then lower under control.'),
      _create('Triceps Pressdowns', 'Triceps', ExerciseType.isolation, 2, 'With a machine similar to the lat pulldown, grasp the bar in front of you with a close grip (hands eight inches apart) with your elbows tucked in at the sides of your waist. There should be no “traveling” of the upper arms away from the tucked-at-the-waist, stable position or the pectorals and latissimus dorsi will come into play. Extend the bar downwards with the body held straight up so that body leverage does not aid in the movement. Lock the elbows firmly at the bottom and pause momentarily before allowing the bar to return slowly to the extended position.'),
      _create('Dips', 'Shoulder, Triceps, Chest', ExerciseType.compound, 4, 'Take hold of the handles on a set of dipping bars and press yourself up to the top lock-out position so that your body weight is supported by your arms. Slowly lower yourself down until you feel a comfortable stretch in your pectoral muscles and then after a brief pause, press yourself back to the starting position. You can place more emphasis on the pecs by allowing your upper arms to flare out away from the torso—the exact opposite advice when using dips to stimulate the triceps.'),
      _create('Cable Crossovers', 'Chest', ExerciseType.isolation, 2, 'Stand between two high pulleys. Take hold of the handles at the end of each cable, bending your elbows 20 to 30 degrees, and start each exercise in the back position where the elbows are slightly behind the plane of the torso. Move against the resistance slowly until both hands have been drawn down and across the midline of your torso. Pause in this fully contracted position, then lower under control.'),
      _create('Pec Deck', 'Chest', ExerciseType.isolation, 2, 'Sit down inside the machine and position your lower arms perpendicular to the floor with your forearms flat against the movement pads. Push evenly against both pads at once, ending the rep when the movement arms meet in the middle. Pause in the contracted position, then perform the negative part of the movement under control'),
      _create('Bench Press', 'Chest, Triceps', ExerciseType.compound, 4, 'Start with the weight at arms’ length with your elbows locked (some machines require that you start with the weight in the bottom position). Your hands should be spaced slightly closer than shoulder width, with the elbows flared away from the torso, back toward the ears. Under very strict control, lower the weight to the upper part of the chest, just in front of the clavicles, or shoulder bones. With little pause, press back to the top where the arms are straight and elbows locked; then lower under control.'),
      _create('Dumbbell Pullovers', 'Back', ExerciseType.isolation, 2, 'Lie on your back on a flat bench with your feet on the floor. Use one dumbbell, holding it in both hands in a straight-arm position over your head. Lower the dumbbell as far back as possible behind your head. Pause briefly and then return to the starting position.'),
      _create('Nautilus Machine Pullovers', 'Back', ExerciseType.isolation, 2, 'Sit erect inside the pullover machine and fasten the seat belt. Push down on the foot pedal to move the elbow pads into position so that you can place your upper arms on the pads. Allow the upper arms to be stretched behind as far as comfortable. Then press the pads and move the elbows to a position just behind the torso. Pause in this fully-contracted position for a moment and then control the return of your upper arms to the fully stretched starting position.'),
      _create('Barbell Rows', 'Back', ExerciseType.isolation, 2, 'Stand directly behind the bar while bending over so your back is as flat as possible, parallel to the floor with your head up. Grasp the bar with a shoulder-width grip, and without changing your back position, rise up slightly so the barbell is not touching the floor. Then row, by pulling the bar straight up so it hits the lower chest area. Because of the physics involved, this is one exercise in which you won’t be able to hold the bar statically at the top of the movement. Just lower the bar under control, and repeat.'),
      _create('One-Arm Dumbbell Rows', 'Back', ExerciseType.isolation, 2, 'One-arm dumbbell rows are performed in essentially the same manner as the barbell row except you’re supporting your torso with your free hand on the end of a bench or chair while rowing the dumbbell with your other hand. Row the dumbbell as high as you can—slightly above the plane of the torso—pause briefly, and lower under control. Perform one set of 6 to 10 repetitions until failure. Then rest as little as is required after completing the prescribed number of reps, and repeat with the other arm.'),
      _create('Rowing Machines', 'Back', ExerciseType.isolation, 2, 'While sitting upright on the seat pad, arch your back with your chest touching the pad directly in front of you. Grab the handles, and row under strict control. Once you’re in as fully contracted a position as you can achieve, pause for two to three seconds and lower under control.'),
      _create('Chin-Ups', 'Back, Biceps', ExerciseType.compound, 4, 'Take an underhand grip on an overhead chin-up bar. Allow your arms to hold your entire body weight. Next, draw your feet up behind your knees so that they are off the floor and slowly pull yourself up until your chin clears the top of the bar. Pause briefly in this fully-contracted position and then lower yourself under control back to the starting position.'),
      _create('Shrugs', 'Back', ExerciseType.isolation, 2, 'Start the movement with the weight at arms’ length. Think of your arms as chains (straight up and down) with hooks on the ends (your hands). Without bending your arms, merely shrug your shoulders straight up toward your ears as far as they’ll go—there’s no rolling of the shoulders. If your back is rounded, the traps cannot be contracted fully. Hold the top position for a couple of seconds and then lower under control.'),
      _create('Leg Curls', 'Legs', ExerciseType.isolation, 2, 'Lie face down on the machine in a position so that your Achilles tendons are braced under the pad of the movement arm and the knees are on the edge of the bench. Initiate the movement deliberately, with no sudden jerking or thrusting to get the weight started. Proceed likewise in a deliberate manner until you have curled your lower legs as high as they can go; until the movement arm pads touch the buttocks (if possible). Pause for two or three seconds in the top position; and lower under control.'),
      _create('Squats', 'Legs, Abdominals, Calf', ExerciseType.compound, 5, 'Place the bar on the upper back, below the nape of the neck, across the trapezius. With feet slightly wider than shoulder width and angled outward, descend in deep-knee-bend fashion with your back flat and head up until the thighs are parallel to the ground, and no lower. Then immediately, without any bouncing, begin a controlled ascent to the top, straight-legged position. Once you’ve reached the top, pause only long enough to take a deep breath. Repeat.'),
      _create('Toe Presses', 'Calf', ExerciseType.isolation, 2, 'Place the balls of the feet on the leg press and keep the knees locked while performing this exercise. The foot should be allowed to stretch back as far as possible before starting the toe press. From there the weight should move deliberately to a fully contracted position and be held for a pause before returning slowly to the bottom stretched position.'),
      _create('Donkey Calf Raises', 'Calf', ExerciseType.isolation, 2, 'Place your heels on a block of wood so that your calves can lower below a parallel position with the balls of your feet. Lean over and place your forearms onto a padded flat bench that should be elevated to a level so that your torso is bent forward at no more than a 90-degree angle to your legs. Have your assistant or training partner climb onto your lower back and sit up straight so that the resistance of his body weight is directly above your hips. Slowly, using only the strength of your calf muscles, rise up on tiptoes, making sure to flex your calves maximally at the top or fully contracted position. Pause for a moment and then lower your heels back down into the pre-stretched starting position.'),
      _create('Hanging Leg Raises', 'Abdominals', ExerciseType.isolation, 2, 'Hanging by your hands from a chinning bar, raise your legs with knees straight until your feet touch the bar. Then lower your legs very strictly under control.'),
      _create('Nautilus Lateral Raises', 'Shoulder', ExerciseType.isolation, 2, 'Sit down in the machine with your back flat against the pad. Place your hands on the handles with the backs of your wrists flush against the pads on the movement arms. Slowly, by the strength of your shoulders alone, raise the movement arms up until they are parallel with your shoulders. Pause briefly in this fully contracted position and then lower the resistance slowly under control back to the starting position.'),
      _create('Bent-Over Cable Laterals', 'Shoulder', ExerciseType.isolation, 2, 'Stand between two overhead pulleys and take hold of the handle for the pulley on your left with your right hand and the pulley on your right with your left hand. Bending over at the waist at a 90-degree angle and with your arms only slightly bent, draw your arms up and back until they are just behind your torso. Hold briefly in this fully contracted position and then lower slowly under control.'),
      _create('Upright Rows', 'Biceps, Back, Shoulder', ExerciseType.compound, 4, 'Use a shoulder-width grip and raise the bar to nipple level, pause, and lower. Don’t use so much weight that you start swinging it up. Bending back will give you a leverage advantage, so keep a straight back while performing this exercise.'),
      _create('Press Behind Neck', 'Shoulder, Triceps', ExerciseType.compound, 4, 'Take a shoulder-width grip in this exercise and keep the elbows directed to the sides so that the resistance is directed onto the delts as much as possible. Perform the movement in a slow and deliberate manner, pausing at the top before lowering under control.'),
      _create('Machine Presses', 'Shoulder, Triceps', ExerciseType.compound, 4, 'Sit down with your back flat against the pad. Take hold of the handles and press upwards. Make it a point to keep the elbows directed to the sides so that the resistance is directed onto the delts as much as possible. Perform the movement in a slow and deliberate manner, pausing at the top before lowering under control.'),
      _create('Standing Barbell Curls', 'Biceps', ExerciseType.isolation, 2, 'Standing behind the bar, bend down with your back straight and head up. Grasp the bar with a shoulder-width grip and stand up. Without any sudden jerking, yanking, or thrusting to get the weight started, curl the bar under strict control while keeping your elbows tucked in at the waist. Allow the arms to extend fully at the bottom and curl all the way to the contracted position where the bar touches the clavicles. Upon reaching the top, pause only slightly and lower under control. On the last two or so hard reps it’s all right to use a slight hitch to get the weight started, but be sure to muscle it up as much as possible. Keep the elbows stable and tucked in to your sides with the hands held slightly wider. You will notice that the hardest part of the curl is at the point when the forearms are in a position perfectly parallel to the floor. This is the only point in the range of motion where you have direct resistance because here you will be pulling straight up, while the bar is being pulled straight down. It is important that you fight the weight through that point, rather than lean back with the body as leverage to help.'),
      _create('Preacher Curls', 'Biceps', ExerciseType.isolation, 2, 'When doing this exercise, use a bench that has a slope of 90 degrees, or is perfectly perpendicular to the ground. This will ensure resistance at the top of the curl, which will greatly enhance the stimulation the biceps receive. The elbows should be pulled in as tight as possible, with the hands positioned slightly wider than the elbows, causing the forearms to form a V shape. Allow the arms to extend fully at the bottom of the movement, but be careful not to jerk the weight out of that position. Curl the weight slowly and deliberately from the bottom, pausing momentarily at the top before lowering slowly.'),
      _create('Concentration Curls', 'Biceps', ExerciseType.isolation, 2, 'Begin the curl by taking hold of a dumbbell with your right hand with your arm hanging perpendicular and resting against the inside of your right thigh. From this “dead-hang” position, slowly curl the dumbbell up toward your left shoulder. As you proceed through the range of motion, supinate your hand so that the inside plate of the dumbbell touches the anterior delt of your left shoulder at the point of completion. Pause briefly in this fully contracted position and then lower the weight slowly under control.'),
      _create('Nautilus Machine Curls', 'Biceps', ExerciseType.isolation, 2, 'Sit down in the Nautilus curl machine and place your elbows on the pad in front of you. You should set the seat so that the pad is approximately level with your shoulders. Grasp hold of the handles and curl both arms up into the position of full contraction. Hold this position briefly before slowly lowering the weight back to the starting position.'),
      _create('Lying Triceps Extensions', 'Triceps', ExerciseType.isolation, 2, 'With the head held off the edge of a bench for greater stretch in the extended position, and your arms locked out as if performing a bench press, let the bar down slowly from a position over the forehead slightly below the plane of the bench. Be careful to extend the forearms slowly with no sudden thrust back to the starting position. The elbows tend to be a delicate articulation and any sudden movements from the extended position can cause severe injury to the area, especially when appreciable weights are being handled. Pause briefly in this extended position and then press the weight back slowly to the starting position.'),
      _create('Nautilus Triceps Extensions', 'Triceps', ExerciseType.isolation, 2, 'Sit down in the Nautilus triceps machine so that your back is against the pad. Place your hands and elbows on the pads provided. Slowly extend both arms forward until full contraction. Pause in this position and then lower the handles back to the starting position.'),
      _create('French Presses', 'Triceps', ExerciseType.isolation, 2, 'Taking hold of a barbell, press it overhead to arms’ length. From this position, slowly lower the barbell to a point just behind your neck. Make sure that you keep your elbows stationary and as close to your ears as possible throughout the movement. Pause briefly in this fully stretched position and then press the bar back to the starting position.'),
      _create('Close-Grip Bench Presses', 'Chest, Triceps', ExerciseType.compound, 4, 'Lying down on a flat bench, take hold of a barbell with a close grip (your hands should be approximately four inches apart) and lower it slowly to the midpoint of your chest. Pause briefly in this position and then press the weight back to arms’ length.'),
    ];

    for (var t in defaults) {
      await _localRepo!.insertTemplate(t);
      // Removed cloud sync for default templates as per requirements.
      // Defaults now exist only within the local app bundle.
    }
  }

  ExerciseTemplate _create(String name, String muscles, ExerciseType type, int intensity, [String? about]) {
    // ELITE CLOUD MAPPING: Generate the Supabase Storage URL from the name using SNAKE_CASE
    // Example: "Dumbbell Flyes" -> "https://fmudyebwpvpgqbnrjtpi.supabase.co/storage/v1/object/public/exercise-photos/dumbbell_flyes.webp"
    final String fileName = name.toLowerCase()
        .replaceAll(' ', '_')
        .replaceAll('-', '_')
        .replaceAll('(', '')
        .replaceAll(')', '');
    final String publicUrl = 'https://fmudyebwpvpgqbnrjtpi.supabase.co/storage/v1/object/public/exercise-photos/$fileName.webp';

    final String citedAbout = '"$about"\n\n— Mike Mentzer, High Intensity Training: The Mike Mentzer Way';

    return ExerciseTemplate(
      name: name,
      targetMuscles: muscles,
      type: type,
      intensity: intensity,
      isDefault: true,
      aboutTheMovement: citedAbout,
      imageUrl: publicUrl,
    );
  }

  Future<void> addTemplate(ExerciseTemplate template) async {
    if (_localRepo == null) return;
    
    // Add or Update in local list first for instant UI feedback
    final localTemplate = template.copyWith(
      name: template.name.trim().toUpperCase(),
      isSynced: 0
    );
    
    // Seamless update: remove old version if exists and add new one
    _templates.removeWhere((t) => t.id == localTemplate.id);
    _templates.add(localTemplate);
    _templates.sort((a, b) => a.name.compareTo(b.name));
    notifyListeners();

    try {
      await _localRepo!.insertTemplate(localTemplate);
      // Only sync to cloud if it is a custom exercise
      if (!localTemplate.isDefault) {
        await _syncTemplate(localTemplate);
      }
    } catch (e) {
      debugPrint("ExerciseProvider: Error adding template locally: $e");
    }
  }

  Future<void> _syncTemplate(ExerciseTemplate template) async {
    try {
      await _cloudRepo.insertTemplate(template);
      await _localRepo!.markTemplateSynced(template.id);
      
      // Update the sync status in memory without triggering a full re-sort if possible
      final idx = _templates.indexWhere((t) => t.id == template.id);
      if (idx != -1) {
        _templates[idx] = template.copyWith(isSynced: 1);
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Background Sync Error (Exercise Template Add): $e");
    }
  }

  Future<void> deleteTemplate(String id) async {
    if (_localRepo == null) return;
    _templates.removeWhere((t) => t.id == id);
    notifyListeners();
    try {
      await _localRepo!.deleteTemplate(id);
      await _localRepo!.addToDeletionQueue(id);
      _syncTemplateDelete(id);
    } catch (e) {
      debugPrint("ExerciseProvider: Error deleting template locally: $e");
    }
  }

  Future<void> _syncTemplateDelete(String id) async {
    try {
      await _cloudRepo.deleteTemplate(id);
      await _localRepo!.removeFromDeletionQueue(id);
    } catch (e) {
      debugPrint("Background Sync Error (Exercise Template Delete): $e");
    }
  }

  Future<void> forceResetDefaults() async {
    if (_localRepo == null) return;
    _isLoading = true;
    notifyListeners();
    
    try {
      // 1. Delete all existing default templates
      final existing = await _localRepo!.getAllTemplates();
      for (var t in existing.where((t) => t.isDefault)) {
        await _localRepo!.deleteTemplate(t.id);
        // We don't delete from cloud to avoid affecting other devices, 
        // unless you want a total reset.
      }
      
      // 2. Re-initialize
      await _initializeDefaults();
      
      // 3. Re-load
      _templates = await _localRepo!.getAllTemplates();
      debugPrint("ExerciseProvider: Force reset complete. Loaded ${_templates.length} templates.");
    } catch (e) {
      debugPrint("ExerciseProvider: Force Reset Error: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> forceRefresh() async {
    if (_localRepo == null) return;
    _isLoading = true;
    notifyListeners();
    
    try {
      debugPrint("ExerciseProvider: FORCE REFRESH TRIGGERED");
      
      // Update Cache Buster to force re-download of all images
      _imageVersion = DateTime.now().millisecondsSinceEpoch;
      debugPrint("ExerciseProvider: Cache Buster updated to v=$_imageVersion");

      // 1. Run self-healing to fix any broken default URLs
      await _runSelfHealingCheck();
      
      // 2. Sync any local changes first
      await _syncWithCloud();
      
      // 3. Perform a fresh load from local
      _templates = await _localRepo!.getAllTemplates();
      debugPrint("ExerciseProvider: Force Refresh Complete.");
    } catch (e) {
      debugPrint("ExerciseProvider: Force Refresh Error: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- Sharing Methods ---

  Future<String?> generateShareableLink(ExerciseTemplate template, String userName) async {
    final Map<String, dynamic> shareData = {
      'type': 'exercise',
      'name': template.name,
      'target_muscles': template.targetMuscles,
      'intensity': template.intensity,
      'exercise_type': template.type.name,
      'about': template.aboutTheMovement,
      'image_url': template.imageUrl,
      'sender': userName,
    };

    try {
      final response = await _supabase.from('shared_data').insert({
        'data': shareData,
      }).select('id').single();

      final shareId = response['id'] as String;
      return "https://heavydutyapp.org/share/exercise?id=$shareId&from=${Uri.encodeComponent(userName)}";
    } catch (e) {
      debugPrint("ExerciseProvider: Error generating share link: $e");
      return null;
    }
  }

  Future<Map<String, dynamic>?> fetchSharedExercise(String shareId) async {
    try {
      final response = await _supabase.from('shared_data').select().eq('id', shareId).single();
      final createdAt = DateTime.parse(response['created_at']);
      if (DateTime.now().difference(createdAt).inDays >= 7) return {'expired': true};
      return response['data'] as Map<String, dynamic>;
    } catch (e) {
      debugPrint("ExerciseProvider: Error fetching shared exercise: $e");
      return null;
    }
  }

  Future<void> importSharedExercise(Map<String, dynamic> data) async {
    final template = ExerciseTemplate(
      id: const Uuid().v4(),
      name: (data['name'] as String).toUpperCase(),
      targetMuscles: data['target_muscles'],
      intensity: data['intensity'] as int? ?? 3,
      type: ExerciseType.values.firstWhere(
        (e) => e.name == data['exercise_type'],
        orElse: () => ExerciseType.isolation,
      ),
      aboutTheMovement: data['about'],
      imageUrl: data['image_url'],
      sharedBy: data['sender'] as String?,
      isSynced: 0,
    );

    await addTemplate(template);
  }

  void clearUserData() {
    ConnectivityService().removeReconnectListener(_onReconnect);
    _realtimeChannel?.unsubscribe();
    _templates.clear();
    _localRepo = null;
    notifyListeners();
  }
}
