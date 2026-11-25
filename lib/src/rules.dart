import 'package:studio_core/core/arcade.dart';
import 'package:studio_core/core/level_plan.dart';
import 'package:studio_core/core/missions.dart';
import 'package:studio_core/core/stats.dart';
import 'hockey_engine.dart';

class AirHockeyRules extends ArcadeRules<HockeyLevel> {
  @override
  String get gameId => 'oyun-hava-hokeyi';

  @override
  List<String> get optionalMechanics => const [];

  /// İki kişilik: "Bilgisayara karşı" ve "Çevrimiçi masa" (gerçek zamanlı düello).
  @override
  int get localPlayers => 2;

  @override
  List<GameStat> get gameStats => const [
        GameStat('goals_scored', 'Atılan gol', 'Goals scored', scale: 500),
        GameStat('matches_won', 'Kazanılan maç', 'Matches won', scale: 40),
        GameStat('saves', 'Kurtarış', 'Saves', scale: 300),
        GameStat('best_streak', 'Üst üste gol', 'Goal streak', scale: 20),
      ];

  @override
  List<MissionTemplate> get missionTemplates => const [
        MissionTemplate('goals_scored', 'goals_scored', [60, 120, 250]),
        MissionTemplate('matches_won', 'matches_won', [5, 10, 20], coinReward: 80),
      ];

  @override
  HockeyLevel generate(LevelSpec spec) => generateHockey(spec);

  @override
  ArcadeMeta metaOf(HockeyLevel l) => l.meta;

  @override
  ArcadeSim createSim(HockeyLevel l) => HockeySim(l);

  @override
  ArcadeInput bot(ArcadeSim sim) => hockeyBot(sim);
}

ArcadeRules createRules() => AirHockeyRules();
