import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:yerel_rehber_app/colors.dart';
import 'package:yerel_rehber_app/data/repo/guide_repository.dart';
import 'package:yerel_rehber_app/data/repo/public_repo.dart';
import 'package:yerel_rehber_app/data/repo/payment_service.dart';
import 'package:yerel_rehber_app/ui/cubit/all_cities_cubit.dart';
import 'package:yerel_rehber_app/ui/cubit/city_cubit.dart';
import 'package:yerel_rehber_app/ui/cubit/guide_cubit.dart';
import 'package:yerel_rehber_app/ui/cubit/home_page_cubit.dart';
import 'package:yerel_rehber_app/ui/cubit/home_page_hotels_cubit.dart';
import 'package:yerel_rehber_app/ui/cubit/home_page_restaurant.dart';
import 'package:yerel_rehber_app/ui/cubit/language_cubit.dart';
import 'package:yerel_rehber_app/ui/views/bottom_navigation.dart';
import 'package:yerel_rehber_app/ui/views/guide_registration/guide_registration_flow.dart';
import 'package:yerel_rehber_app/ui/views/guide_registration/steps/photo_selection_page.dart';
import 'package:yerel_rehber_app/ui/views/guide_registration/steps/biography_page.dart';
import 'package:yerel_rehber_app/ui/views/guide_registration/steps/language_selection_page.dart';
import 'package:yerel_rehber_app/ui/views/guide_registration/guide_info_page.dart';
import 'package:yerel_rehber_app/ui/views/guide_registration/steps/guide_photos_page.dart';
import 'package:yerel_rehber_app/ui/views/guide_registration/steps/guide_bio_page.dart';
import 'package:yerel_rehber_app/ui/views/guide_registration/steps/guide_languages_page.dart';
import 'package:yerel_rehber_app/blocs/guide_languages/guide_languages_bloc.dart';
import 'package:yerel_rehber_app/blocs/guide_city/guide_city_bloc.dart';
import 'package:yerel_rehber_app/blocs/guide_routes/guide_routes_bloc.dart';
import 'package:yerel_rehber_app/ui/views/guide_registration/steps/guide_city_page.dart';
import 'package:yerel_rehber_app/ui/views/guide_registration/steps/guide_routes_page.dart';
import 'package:yerel_rehber_app/ui/views/guide_registration/steps/guide_success_page.dart';
import 'package:yerel_rehber_app/ui/views/auth/login_pages.dart';
import 'package:yerel_rehber_app/ui/views/profile_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:yerel_rehber_app/ui/views/payment_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await dotenv.load(fileName: ".env");
  await PaymentService.initializeStripe();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  final travelRepo = TravelRepository();
  final guideRepo = GuideRepository();

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (context) => LanguageCubit()),
        BlocProvider(create: (context) => AllCitiesCubit()),
        BlocProvider(create: (context) => HomePageCubit()),
        BlocProvider(create: (context) => HomePageHotelsCubit(travelRepo)),
        BlocProvider(create: (context) => RestaurantCubit(travelRepo)),
        BlocProvider(create: (context) => CityCubit(repository: travelRepo)),
        BlocProvider(create: (context) => GuideLanguagesBloc()),
        BlocProvider(create: (context) => GuideCityBloc()),
        BlocProvider(create: (context) => GuideRoutesBloc()),
        BlocProvider(create: (context) => GuideCubit(guideRepo)),
      ],
      child: MaterialApp(
        title: 'Yerel Rehber',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primaryColor: mainColor,
          scaffoldBackgroundColor: Colors.white,
          appBarTheme: AppBarTheme(
            backgroundColor: Colors.white,
            elevation: 0,
            iconTheme: IconThemeData(color: mainColor),
            titleTextStyle: TextStyle(
              color: mainColor,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        initialRoute: '/',
        routes: {
          '/': (context) => StreamBuilder<User?>(
                stream: FirebaseAuth.instance.authStateChanges(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Scaffold(
                      backgroundColor: Colors.white,
                      body: Center(
                        child: CircularProgressIndicator(
                          color: mainColor,
                          strokeWidth: 2,
                        ),
                      ),
                    );
                  } else if (snapshot.hasData && snapshot.data != null) {
                    return FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance
                          .collection('Users')
                          .doc(snapshot.data!.uid)
                          .get(),
                      builder: (context, userSnapshot) {
                        if (userSnapshot.connectionState ==
                            ConnectionState.waiting) {
                          return Scaffold(
                            backgroundColor: Colors.white,
                            body: Center(
                              child: CircularProgressIndicator(
                                color: mainColor,
                                strokeWidth: 2,
                              ),
                            ),
                          );
                        } else if (userSnapshot.hasData &&
                            userSnapshot.data!.exists) {
                          return const BottomNavigation_();
                        } else {
                          FirebaseAuth.instance.signOut();
                          return const LoginPages2();
                        }
                      },
                    );
                  } else {
                    return const LoginPages2();
                  }
                },
              ),
          '/photo_selection': (context) => const PhotoSelectionPage(),
          '/biography': (context) => const BiographyPage(),
          '/language_selection': (context) => const LanguageSelectionPage(),
          '/guide_registration': (context) => const GuideRegistrationFlow(),
          '/guide_info': (context) => const GuideInfoPage(),
          '/guide_languages': (context) => const GuideLanguagesPage(),
          '/guide_city': (context) => const GuideCityPage(),
          '/guide_routes': (context) => const GuideRoutesPage(),
          '/guide_success': (context) => const GuideSuccessPage(),
          '/profil_page': (context) => const ProfilPage(),
          '/guide_photos': (context) => const GuidePhotosPage(),
          '/guide_bio': (context) => const GuideBioPage(),
        },
      ),
    );
  }
}
