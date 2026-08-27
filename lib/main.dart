import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const SanteApp());

const kBleu = Color(0xFF1D4E89);
const kRouge = Color(0xFFE63946);
const kVert = Color(0xFF4C8C4A);
const kOrange = Color(0xFFE8871E);
const kInk = Color(0xFF0B1F2A);

String greeting() {
  final h = DateTime.now().hour;
  if (h < 5) return "Bonne nuit";
  if (h < 12) return "Bonjour";
  if (h < 18) return "Bon après-midi";
  return "Bonsoir";
}

// ---------------- STORE (singleton ChangeNotifier, comme Damli) ----------------
class AppStore extends ChangeNotifier {
  AppStore._();
  static final AppStore instance = AppStore._();

  String name = "Utilisateur";
  int age = 25;
  double weightKg = 70;
  String goal = "Maintien du poids";
  int dailyGoalKcal = 1850;
  int consumedKcal = 0;

  String _todayKey() {
    final d = DateTime.now();
    return "${d.year}-${d.month}-${d.day}";
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    name = prefs.getString('name') ?? name;
    age = prefs.getInt('age') ?? age;
    weightKg = prefs.getDouble('weightKg') ?? weightKg;
    goal = prefs.getString('goal') ?? goal;
    dailyGoalKcal = prefs.getInt('dailyGoalKcal') ?? dailyGoalKcal;
    consumedKcal = (prefs.getString('consumedDate') == _todayKey()) ? (prefs.getInt('consumedKcal') ?? 0) : 0;
    notifyListeners();
  }

  Future<void> saveProfile({required String name, required int age, required double weightKg, required String goal, required int dailyGoalKcal}) async {
    this.name = name;
    this.age = age;
    this.weightKg = weightKg;
    this.goal = goal;
    this.dailyGoalKcal = dailyGoalKcal;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('name', name);
    await prefs.setInt('age', age);
    await prefs.setDouble('weightKg', weightKg);
    await prefs.setString('goal', goal);
    await prefs.setInt('dailyGoalKcal', dailyGoalKcal);
    notifyListeners();
  }

  Future<void> addKcal(int kcal) async {
    consumedKcal += kcal;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('consumedKcal', consumedKcal);
    await prefs.setString('consumedDate', _todayKey());
    notifyListeners();
  }

  Future<void> resetToday() async {
    consumedKcal = 0;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('consumedKcal', 0);
    await prefs.setString('consumedDate', _todayKey());
    notifyListeners();
  }
}

class SanteApp extends StatelessWidget {
  const SanteApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Santé & Bien-être',
      theme: ThemeData(fontFamily: 'Poppins', scaffoldBackgroundColor: Colors.white, useMaterial3: false),
      home: const RootShell(),
    );
  }
}

// ---------------- COQUILLE PRINCIPALE (4 onglets réels) ----------------
class RootShell extends StatefulWidget {
  const RootShell({super.key});
  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int index = 0;

  @override
  void initState() {
    super.initState();
    AppStore.instance.load();
  }

  void goTo(int i) => setState(() => index = i);

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeScreen(onNavigate: goTo),
      const UrgenceScreen(),
      const NutritionScreen(),
      const ProfilScreen(),
    ];
    return Scaffold(
      body: SafeArea(child: IndexedStack(index: index, children: screens)),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: index,
        onTap: goTo,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: kBleu,
        unselectedItemColor: const Color(0xFFB7BFC6),
        items: const [
          BottomNavigationBarItem(icon: Icon(CupertinoIcons.house_fill), label: "Accueil"),
          BottomNavigationBarItem(icon: Icon(CupertinoIcons.heart_fill), label: "Urgence"),
          BottomNavigationBarItem(icon: Icon(CupertinoIcons.leaf_arrow_circlepath), label: "Nutrition"),
          BottomNavigationBarItem(icon: Icon(CupertinoIcons.person_fill), label: "Profil"),
        ],
      ),
    );
  }
}

class Topic {
  final IconData icon;
  final String label;
  final Color color;
  const Topic(this.icon, this.label, this.color);
}

const firstAidTopics = [
  Topic(CupertinoIcons.heart_fill, "Arrêt cardiaque", kRouge),
  Topic(CupertinoIcons.flame_fill, "Brûlure", Color(0xFFE76F51)),
  Topic(CupertinoIcons.bandage_fill, "Fracture", kBleu),
  Topic(CupertinoIcons.drop_fill, "Hémorragie", Color(0xFFD62828)),
  Topic(CupertinoIcons.wind, "Étouffement", Color(0xFF1D4E89)),
];

const recipes = [
  {"name": "Riz au poisson & légumes", "kcal": "420", "tag": "Marché local"},
  {"name": "Salade de mangue & arachides", "kcal": "260", "tag": "Rapide"},
  {"name": "Bouillie de mil & fruits", "kcal": "310", "tag": "Petit-déj"},
];

const emergencyNumbers = [
  {"label": "SAMU", "number": "15"},
  {"label": "Sapeurs-pompiers", "number": "18"},
  {"label": "Police", "number": "17"},
  {"label": "Gendarmerie", "number": "123"},
  {"label": "Numéro vert santé", "number": "0800005050"},
];

// ---------------- ACCUEIL ----------------
class HomeScreen extends StatelessWidget {
  final void Function(int) onNavigate;
  const HomeScreen({super.key, required this.onNavigate});
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppStore.instance,
      builder: (context, _) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("${greeting()}, ${AppStore.instance.name}",
                      style: const TextStyle(color: Color(0xFF8A97A3), fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  const Text("Comment on s'occupe de vous ?",
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: kInk)),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                _HomeCard(
                  label: "URGENCE", title: "Premiers secours",
                  subtitle: "Tutoriels guidés, assistance vocale, hôpitaux à proximité",
                  cta: "Agir maintenant", colors: const [kBleu, kRouge],
                  icon: CupertinoIcons.heart_fill, onTap: () => onNavigate(1),
                ),
                const SizedBox(height: 14),
                _HomeCard(
                  label: "NUTRITION", title: "Manger sainement",
                  subtitle: "Recettes locales, valeurs nutritionnelles, conseils personnalisés",
                  cta: "Découvrir", colors: const [kVert, kOrange],
                  icon: CupertinoIcons.leaf_arrow_circlepath, onTap: () => onNavigate(2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeCard extends StatelessWidget {
  final String label, title, subtitle, cta;
  final List<Color> colors;
  final IconData icon;
  final VoidCallback onTap;
  const _HomeCard({
    required this.label, required this.title, required this.subtitle,
    required this.cta, required this.colors, required this.icon, required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        height: 150,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Stack(
          children: [
            Positioned(right: -10, top: -10, child: Icon(icon, size: 110, color: Colors.white.withOpacity(0.18))),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.22), borderRadius: BorderRadius.circular(20)),
                  child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 10),
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                SizedBox(width: 220, child: Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13))),
                const Spacer(),
                Row(children: [
                  Text(cta, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right, size: 16, color: Colors.white),
                ]),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------- URGENCE ----------------
class UrgenceScreen extends StatelessWidget {
  const UrgenceScreen({super.key});

  Future<void> _callNumber(String number) async {
    final uri = Uri(scheme: 'tel', path: number);
    await launchUrl(uri);
  }

  void _showCallSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text("Qui voulez-vous appeler ?", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            ...emergencyNumbers.map((e) => ListTile(
                  leading: const Icon(CupertinoIcons.phone_fill, color: kRouge),
                  title: Text(e["label"]!),
                  trailing: Text(e["number"]!, style: const TextStyle(fontWeight: FontWeight.bold)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _callNumber(e["number"]!);
                  },
                )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _openNearbyHospitals(BuildContext context) async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (context.mounted) _snack(context, "Activez la localisation pour voir les hôpitaux proches");
      return;
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      if (context.mounted) _snack(context, "Autorisation de localisation refusée");
      return;
    }
    final pos = await Geolocator.getCurrentPosition();
    final uri = Uri.parse("https://www.google.com/maps/search/?api=1&query=hopital+near+${pos.latitude},${pos.longitude}");
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _snack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFD),
      appBar: AppBar(
        backgroundColor: kBleu,
        title: const Text("Urgence", style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: kRouge, foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            ),
            onPressed: () => _showCallSheet(context),
            icon: const Icon(CupertinoIcons.phone_fill),
            label: const Text("Appeler les secours", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ),
          const SizedBox(height: 20),
          const Text("Que se passe-t-il ?", style: TextStyle(fontWeight: FontWeight.bold, color: kInk, fontSize: 13)),
          const SizedBox(height: 8),
          GridView.count(
            crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.3,
            children: [
              ...firstAidTopics.map((t) => _TopicCard(
                    topic: t,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TopicScreen(topic: t))),
                  )),
              GestureDetector(
                onTap: () => _openNearbyHospitals(context),
                child: Container(
                  decoration: BoxDecoration(color: const Color(0xFFEAF3FC), borderRadius: BorderRadius.circular(16)),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(CupertinoIcons.map_pin_ellipse, color: kBleu),
                      SizedBox(height: 6),
                      Text("Hôpitaux proches", style: TextStyle(color: kBleu, fontWeight: FontWeight.w600, fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: kInk, borderRadius: BorderRadius.circular(18)),
            child: Row(children: [
              Container(
                width: 42, height: 42,
                decoration: const BoxDecoration(color: kRouge, shape: BoxShape.circle),
                child: const Icon(CupertinoIcons.mic_fill, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Assistant vocal d'urgence", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                    SizedBox(height: 2),
                    Text("Ouvrez un geste ci-dessus puis lancez la lecture vocale des étapes",
                        style: TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

class _TopicCard extends StatelessWidget {
  final Topic topic;
  final VoidCallback onTap;
  const _TopicCard({required this.topic, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFEAF0F5))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(color: topic.color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: Icon(topic.icon, color: topic.color, size: 20),
            ),
            const SizedBox(height: 8),
            Text(topic.label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kInk)),
          ],
        ),
      ),
    );
  }
}

// ---------------- DÉTAIL D'UN GESTE (animation + voix réelles) ----------------
class TopicScreen extends StatefulWidget {
  final Topic topic;
  const TopicScreen({super.key, required this.topic});
  @override
  State<TopicScreen> createState() => _TopicScreenState();
}

class _TopicScreenState extends State<TopicScreen> {
  final FlutterTts tts = FlutterTts();
  Timer? _timer;
  double progress = 0;
  bool playing = false;
  bool speaking = false;
  int currentStep = 0;
  late final List<String> steps;

  @override
  void initState() {
    super.initState();
    tts.setLanguage("fr-FR");
    steps = _stepsFor(widget.topic.label);
  }

  List<String> _stepsFor(String label) {
    switch (label) {
      case "Arrêt cardiaque":
        return [
          "Vérifiez que la personne ne répond pas et ne respire pas normalement",
          "Appelez ou faites appeler les secours immédiatement",
          "Démarrez le massage cardiaque, mains croisées au centre de la poitrine",
          "Comprimez cinq à six centimètres de profondeur, cent à cent vingt fois par minute",
          "Continuez sans interruption jusqu'à l'arrivée des secours",
        ];
      case "Brûlure":
        return [
          "Éloignez la personne de la source de chaleur",
          "Refroidissez la brûlure à l'eau tiède pendant quinze à vingt minutes",
          "Retirez bijoux et vêtements non collés à la peau",
          "Recouvrez d'un linge propre, sans percer les cloques",
          "Consultez un médecin si la brûlure est étendue ou profonde",
        ];
      case "Fracture":
        return [
          "Ne bougez pas le membre blessé",
          "Immobilisez la zone avec une attelle improvisée si possible",
          "Surveillez la sensibilité et la couleur du membre",
          "Appliquez du froid pour limiter le gonflement",
          "Attendez les secours sans forcer sur le membre",
        ];
      case "Hémorragie":
        return [
          "Allongez la personne et rassurez-la",
          "Comprimez fermement la plaie avec un tissu propre",
          "Maintenez la pression en continu, sans relâcher",
          "Surélevez le membre blessé si possible",
          "Appelez les secours si le saignement ne s'arrête pas",
        ];
      case "Étouffement":
      default:
        return [
          "Demandez à la personne de tousser fort",
          "Donnez cinq claques dans le dos entre les omoplates",
          "Si cela ne fonctionne pas, faites cinq compressions abdominales",
          "Alternez claques et compressions jusqu'à désobstruction",
          "Appelez les secours si la personne perd connaissance",
        ];
    }
  }

  void _playAnimation() {
    _timer?.cancel();
    setState(() { playing = true; progress = 0; currentStep = 0; });
    const totalMs = 45000;
    const tickMs = 300;
    _timer = Timer.periodic(const Duration(milliseconds: tickMs), (t) {
      setState(() {
        progress += tickMs / totalMs;
        currentStep = (progress * steps.length).floor().clamp(0, steps.length - 1);
        if (progress >= 1) {
          progress = 1;
          playing = false;
          t.cancel();
        }
      });
    });
  }

  Future<void> _speakSteps() async {
    setState(() => speaking = true);
    await tts.setLanguage("fr-FR");
    await tts.setSpeechRate(0.45);
    for (int i = 0; i < steps.length; i++) {
      if (!mounted) return;
      setState(() => currentStep = i);
      await tts.speak(steps[i]);
      await tts.awaitSpeakCompletion(true);
    }
    if (mounted) setState(() => speaking = false);
  }

  @override
  void dispose() {
    _timer?.cancel();
    tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topic = widget.topic;
    return Scaffold(
      appBar: AppBar(title: Text(topic.label), foregroundColor: kInk, backgroundColor: Colors.white, elevation: 0),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GestureDetector(
            onTap: _playAnimation,
            child: Container(
              height: 150,
              decoration: BoxDecoration(color: topic.color.withOpacity(0.08), borderRadius: BorderRadius.circular(18)),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(topic.icon, size: 54, color: topic.color),
                  if (playing)
                    Positioned(
                      bottom: 10, left: 16, right: 16,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(value: progress, color: topic.color, backgroundColor: topic.color.withOpacity(0.15)),
                      ),
                    ),
                  Positioned(
                    bottom: playing ? 24 : 12, right: 12,
                    child: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(color: topic.color, shape: BoxShape.circle),
                      child: Icon(playing ? Icons.pause : Icons.play_arrow, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            playing ? "Lecture en cours, étape ${currentStep + 1} sur ${steps.length}" : "Animation guidée, 45 sec — touchez pour lancer",
            style: const TextStyle(color: Color(0xFF8A97A3), fontSize: 12),
          ),
          const SizedBox(height: 18),
          const Text("Étapes à suivre", style: TextStyle(fontWeight: FontWeight.bold, color: kInk, fontSize: 14)),
          const SizedBox(height: 8),
          ...List.generate(steps.length, (i) {
            final active = (playing || speaking) && i == currentStep;
            return Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: active ? topic.color.withOpacity(0.08) : Colors.transparent, borderRadius: BorderRadius.circular(12)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 24, height: 24,
                    decoration: BoxDecoration(color: topic.color, shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: Text("${i + 1}", style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(steps[i], style: const TextStyle(fontSize: 13, color: Color(0xFF33414C)))),
                ],
              ),
            );
          }),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: kRouge, foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: speaking ? null : _speakSteps,
            icon: Icon(speaking ? CupertinoIcons.speaker_3_fill : CupertinoIcons.mic_fill),
            label: Text(speaking ? "Lecture vocale en cours..." : "Lancer l'assistance vocale", style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

// ---------------- NUTRITION ----------------
class NutritionScreen extends StatefulWidget {
  const NutritionScreen({super.key});
  @override
  State<NutritionScreen> createState() => _NutritionScreenState();
}

class _NutritionScreenState extends State<NutritionScreen> {
  String query = "";

  void _editGoal(BuildContext context) {
    final store = AppStore.instance;
    final goalCtrl = TextEditingController(text: store.goal);
    final kcalCtrl = TextEditingController(text: "${store.dailyGoalKcal}");
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Modifier mes objectifs"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: goalCtrl, decoration: const InputDecoration(labelText: "Objectif")),
            TextField(controller: kcalCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Objectif calorique quotidien")),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Annuler")),
          ElevatedButton(
            onPressed: () {
              store.saveProfile(
                name: store.name, age: store.age, weightKg: store.weightKg,
                goal: goalCtrl.text, dailyGoalKcal: int.tryParse(kcalCtrl.text) ?? store.dailyGoalKcal,
              );
              Navigator.pop(ctx);
            },
            child: const Text("Enregistrer"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = recipes.where((r) => r["name"]!.toLowerCase().contains(query.toLowerCase())).toList();
    return AnimatedBuilder(
      animation: AppStore.instance,
      builder: (context, _) {
        final store = AppStore.instance;
        final progress = (store.consumedKcal / store.dailyGoalKcal).clamp(0, 1).toDouble();
        return Scaffold(
          backgroundColor: const Color(0xFFFFFBF3),
          appBar: AppBar(backgroundColor: kVert, title: const Text("Nutrition", style: TextStyle(color: Colors.white)), iconTheme: const IconThemeData(color: Colors.white)),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextField(
                onChanged: (v) => setState(() => query = v),
                decoration: InputDecoration(
                  hintText: "Rechercher une recette...",
                  prefixIcon: const Icon(CupertinoIcons.search, size: 18),
                  filled: true, fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFEFE6D6))),
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: kVert, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ScanScreen())),
                icon: const Icon(CupertinoIcons.viewfinder, size: 17),
                label: const Text("Scanner un aliment", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _editGoal(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(color: const Color(0xFFEFF6EC), borderRadius: BorderRadius.circular(14)),
                      child: Column(children: [
                        const Icon(CupertinoIcons.flag_fill, color: kVert, size: 16),
                        const SizedBox(height: 4),
                        const Text("Objectif", style: TextStyle(color: kVert, fontWeight: FontWeight.bold, fontSize: 11)),
                        Text(store.goal, style: const TextStyle(color: Color(0xFF5B6B57), fontSize: 12), textAlign: TextAlign.center),
                      ]),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _editGoal(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(color: const Color(0xFFFDF1E2), borderRadius: BorderRadius.circular(14)),
                      child: Column(children: [
                        const Icon(CupertinoIcons.flame, color: kOrange, size: 16),
                        const SizedBox(height: 4),
                        Text("${store.consumedKcal} / ${store.dailyGoalKcal} kcal", style: const TextStyle(color: kOrange, fontWeight: FontWeight.bold, fontSize: 12)),
                        const Text("objectif du jour", style: TextStyle(color: Color(0xFF8A7358), fontSize: 12)),
                      ]),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(value: progress, minHeight: 8, color: kOrange, backgroundColor: const Color(0xFFFDF1E2)),
              ),
              const SizedBox(height: 18),
              const Text("Recettes du marché local", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF3B3527), fontSize: 13)),
              const SizedBox(height: 8),
              if (filtered.isEmpty) const Text("Aucun résultat", style: TextStyle(color: Color(0xFF9C9484), fontSize: 12)),
              ...filtered.map((r) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFF1EAD9))),
                    child: Row(children: [
                      Container(width: 44, height: 44, decoration: BoxDecoration(color: const Color(0xFFEFF6EC), borderRadius: BorderRadius.circular(12)), child: const Icon(CupertinoIcons.leaf_arrow_circlepath, color: kVert, size: 20)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(r["name"]!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF3B3527))),
                            const SizedBox(height: 2),
                            Text("${r["tag"]} · ${r["kcal"]} kcal", style: const TextStyle(fontSize: 11, color: Color(0xFF9C9484))),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          AppStore.instance.addKcal(int.parse(r["kcal"]!));
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("${r["name"]} ajoutée à votre journal")));
                        },
                        child: const Text("Ajouter"),
                      ),
                    ]),
                  )),
            ],
          ),
        );
      },
    );
  }
}

// ---------------- SCAN (code-barres réel + base alimentaire réelle) ----------------
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});
  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final MobileScannerController controller = MobileScannerController();
  Map<String, dynamic>? product;
  bool loading = false;
  String? error;
  bool scanned = false;

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (scanned) return;
    final code = capture.barcodes.isNotEmpty ? capture.barcodes.first.rawValue : null;
    if (code == null) return;
    setState(() { scanned = true; loading = true; error = null; });
    try {
      final res = await http.get(Uri.parse("https://world.openfoodfacts.org/api/v2/product/$code.json"));
      final data = jsonDecode(res.body);
      if (data["status"] == 1) {
        setState(() { product = data["product"]; loading = false; });
      } else {
        setState(() { error = "Produit introuvable dans la base de données"; loading = false; });
      }
    } catch (e) {
      setState(() { error = "Erreur réseau, réessayez"; loading = false; });
    }
  }

  void _rescan() => setState(() { scanned = false; product = null; error = null; });

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFBF3),
      appBar: AppBar(backgroundColor: kVert, title: const Text("Scanner", style: TextStyle(color: Colors.white)), iconTheme: const IconThemeData(color: Colors.white)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: SizedBox(
              height: 220,
              child: scanned
                  ? Container(color: const Color(0xFFEFF6EC), alignment: Alignment.center, child: const Icon(CupertinoIcons.checkmark_seal_fill, color: kVert, size: 40))
                  : MobileScanner(controller: controller, onDetect: _onDetect),
            ),
          ),
          const SizedBox(height: 10),
          const Text("Visez le code-barres du produit", style: TextStyle(color: Color(0xFF9C9484), fontSize: 12), textAlign: TextAlign.center),
          if (loading) const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator())),
          if (error != null) ...[
            const SizedBox(height: 12),
            Text(error!, style: const TextStyle(color: kRouge), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Center(child: OutlinedButton(onPressed: _rescan, child: const Text("Rescanner"))),
          ],
          if (product != null)
            _ProductCard(
              product: product!,
              onAdd: (kcal) {
                AppStore.instance.addKcal(kcal);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$kcal kcal ajoutées à votre journal")));
                _rescan();
              },
            ),
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Map<String, dynamic> product;
  final void Function(int kcal) onAdd;
  const _ProductCard({required this.product, required this.onAdd});

  Widget _val(String k, String v) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(color: const Color(0xFFFAF7EF), borderRadius: BorderRadius.circular(10)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(k, style: const TextStyle(fontSize: 10, color: Color(0xFF9C9484))),
            Text(v, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF3B3527))),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final name = product["product_name"] ?? "Produit sans nom";
    final nutriments = product["nutriments"] ?? {};
    final kcalNum = nutriments["energy-kcal_100g"];
    final kcal = (kcalNum is num) ? kcalNum.round() : 0;
    final sugars = nutriments["sugars_100g"];
    final fiber = nutriments["fiber_100g"];
    final proteins = nutriments["proteins_100g"];

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFF1EAD9))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF3B3527)))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(color: const Color(0xFFEFF6EC), borderRadius: BorderRadius.circular(20)),
                child: const Text("100 g", style: TextStyle(color: Color(0xFF3B6B39), fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 2.6,
            children: [
              _val("Calories", "$kcal kcal"),
              _val("Sucres", sugars != null ? "$sugars g" : "—"),
              _val("Fibres", fiber != null ? "$fiber g" : "—"),
              _val("Protéines", proteins != null ? "$proteins g" : "—"),
            ],
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kVert, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () => onAdd(kcal),
            child: const Text("Ajouter à mon journal du jour"),
          ),
        ],
      ),
    );
  }
}

// ---------------- PROFIL (réel, persisté) ----------------
class ProfilScreen extends StatefulWidget {
  const ProfilScreen({super.key});
  @override
  State<ProfilScreen> createState() => _ProfilScreenState();
}

class _ProfilScreenState extends State<ProfilScreen> {
  late TextEditingController nameCtrl;
  late TextEditingController ageCtrl;
  late TextEditingController weightCtrl;
  String goal = "Maintien du poids";
  final goals = ["Perte de poids", "Maintien du poids", "Prise de masse"];

  @override
  void initState() {
    super.initState();
    final store = AppStore.instance;
    nameCtrl = TextEditingController(text: store.name);
    ageCtrl = TextEditingController(text: "${store.age}");
    weightCtrl = TextEditingController(text: "${store.weightKg}");
    goal = store.goal;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppStore.instance,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: const Text("Profil"), backgroundColor: Colors.white, foregroundColor: kInk, elevation: 0),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Center(
                child: Container(
                  width: 72, height: 72,
                  decoration: const BoxDecoration(color: kBleu, shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: Text(
                    nameCtrl.text.isNotEmpty ? nameCtrl.text[0].toUpperCase() : "?",
                    style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text("Nom", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF8A97A3))),
              TextField(controller: nameCtrl, onChanged: (_) => setState(() {})),
              const SizedBox(height: 12),
              const Text("Âge", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF8A97A3))),
              TextField(controller: ageCtrl, keyboardType: TextInputType.number),
              const SizedBox(height: 12),
              const Text("Poids (kg)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF8A97A3))),
              TextField(controller: weightCtrl, keyboardType: TextInputType.number),
              const SizedBox(height: 12),
              const Text("Objectif santé", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF8A97A3))),
              DropdownButton<String>(
                value: goal, isExpanded: true,
                items: goals.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                onChanged: (v) => setState(() => goal = v!),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: kBleu, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                onPressed: () {
                  AppStore.instance.saveProfile(
                    name: nameCtrl.text.isEmpty ? "Utilisateur" : nameCtrl.text,
                    age: int.tryParse(ageCtrl.text) ?? 0,
                    weightKg: double.tryParse(weightCtrl.text) ?? 0,
                    goal: goal,
                    dailyGoalKcal: AppStore.instance.dailyGoalKcal,
                  );
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profil enregistré")));
                },
                child: const Text("Enregistrer le profil", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () {
                  AppStore.instance.resetToday();
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Journal du jour réinitialisé")));
                },
                child: const Text("Réinitialiser le journal du jour"),
              ),
            ],
          ),
        );
      },
    );
  }
}
