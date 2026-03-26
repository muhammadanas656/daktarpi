import sys

f = 'c:\\skills development\\daktarpi\\lib\\features\\doctors\\presentation\\screens\\specialty_doctors_screen.dart'
try:
    with open(f, 'r', encoding='utf-8') as file:
        c = file.read()
except:
    print("Could not read")
    sys.exit(1)

imports = "import '../../../../presentation/widgets/doctor_list_card.dart';"
new_imports = "import '../../../../presentation/widgets/doctor_list_card.dart';\nimport '../../../../presentation/widgets/animations/squishy_button.dart';\nimport '../../../../presentation/widgets/animations/staggered_fade_in.dart';\nimport '../../../../presentation/widgets/animations/dynamic_glass_shelf_delegate.dart';"
c = c.replace(imports, new_imports)

c = c.replace("delegate: _DynamicGlassShelfDelegate(", "delegate: DynamicGlassShelfDelegate(")

# Slice off the trailing classes
cutoff = c.find("class _SquishableDoctorCard extends StatefulWidget {")
if cutoff != -1:
    c = c[:cutoff]
else:
    print("Couldn't find trailing classes to cut")

# Replace the bulky Tween Animation
old_tween = """                    return TweenAnimationBuilder<double>(
                      key: ValueKey(docId), 
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: Duration(milliseconds: 300 + (index.clamp(0, 8) * 40)), 
                      curve: Curves.easeOutQuart,
                      builder: (context, value, child) {
                        return Transform.translate(
                          offset: Offset(0, 20 * (1 - value)), 
                          child: Opacity(opacity: value, child: child),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _SquishableDoctorCard(
                          doctor: doctor,
                          docId: docId,
                          specialtyName: specialtyName,
                          favNotifier: _favNotifier,
                          heroTagPrefix: 'specialty-',
                        ),
                      ),
                    );"""

new_stagger = """                    return StaggeredFadeIn(
                      index: index,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: SquishyButton(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            context.push(AppRoutes.doctorDetailsById('${docId}'), extra: doctor);
                          },
                          child: DoctorListCard(
                            id: docId,
                            name: doctor['full_name'] ?? 'Unknown',
                            specialty: " ${specialtyName}",
                            rating: doctor['rating']?.toString() ?? '0.0',
                            views: (doctor['views_count'] ?? 0).toString(),
                            imageUrl: doctor['profile_picture_url'],
                            isFavorite: _favNotifier.isFavorite(docId),
                            heroTagPrefix: 'specialty-',
                            onFavoriteTap: () {
                              HapticFeedback.selectionClick(); 
                              _favNotifier.toggle(doctor);
                            },
                            onCardTap: () {},
                          ),
                        ),
                      ),
                    );"""

c = c.replace(old_tween, new_stagger)

with open(f, 'w', encoding='utf-8') as file:
    file.write(c)

print('Success specialty')
