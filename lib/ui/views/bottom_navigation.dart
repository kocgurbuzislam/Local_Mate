import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:yerel_rehber_app/data/repo/guide_repository.dart';
import 'package:yerel_rehber_app/ui/cubit/guide_cubit.dart';
import 'package:yerel_rehber_app/ui/views/guides.dart';
import 'package:yerel_rehber_app/ui/views/home_page.dart';
import 'package:yerel_rehber_app/ui/views/chat_list_screen.dart';
import 'package:yerel_rehber_app/ui/views/profile_page.dart';
import 'package:google_fonts/google_fonts.dart';

class BottomNavigation_ extends StatefulWidget {
  const BottomNavigation_({super.key});

  @override
  State<BottomNavigation_> createState() => _BottomNavigationState();
}

class _BottomNavigationState extends State<BottomNavigation_> {
  int selectIndeks = 0;
  late List<Widget> pages;

  @override
  void initState() {
    super.initState();
    pages = [
      const HomePage(),
      const GuideScreen(),
      const ChatListScreen(),
      const ProfilPage()
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: pages[selectIndeks],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, -5),
              spreadRadius: 0,
            ),
          ],
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
          child: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            items: [
              BottomNavigationBarItem(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: selectIndeks == 0
                        ? const Color(0xFF4B8EC4).withOpacity(0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.home_rounded,
                    color: selectIndeks == 0
                        ? const Color(0xFF4B8EC4)
                        : Colors.grey[600],
                    size: 24,
                  ),
                ),
                label: "Anasayfa",
              ),
              BottomNavigationBarItem(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: selectIndeks == 1
                        ? const Color(0xFF4B8EC4).withOpacity(0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.map_rounded,
                    color: selectIndeks == 1
                        ? const Color(0xFF4B8EC4)
                        : Colors.grey[600],
                    size: 24,
                  ),
                ),
                label: "Rehberler",
              ),
              BottomNavigationBarItem(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: selectIndeks == 2
                        ? const Color(0xFF4B8EC4).withOpacity(0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.chat_bubble_outline_rounded,
                    color: selectIndeks == 2
                        ? const Color(0xFF4B8EC4)
                        : Colors.grey[600],
                    size: 24,
                  ),
                ),
                label: "Mesajlar",
              ),
              BottomNavigationBarItem(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: selectIndeks == 3
                        ? const Color(0xFF4B8EC4).withOpacity(0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.person_outline_rounded,
                    color: selectIndeks == 3
                        ? const Color(0xFF4B8EC4)
                        : Colors.grey[600],
                    size: 24,
                  ),
                ),
                label: "Profil",
              ),
            ],
            currentIndex: selectIndeks,
            backgroundColor: Colors.white,
            selectedItemColor: const Color(0xFF4B8EC4),
            unselectedItemColor: Colors.grey[600],
            showUnselectedLabels: true,
            showSelectedLabels: true,
            elevation: 0,
            selectedLabelStyle: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            unselectedLabelStyle: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w400,
            ),
            onTap: (index) {
              setState(() {
                selectIndeks = index;
              });
            },
          ),
        ),
      ),
    );
  }
}
