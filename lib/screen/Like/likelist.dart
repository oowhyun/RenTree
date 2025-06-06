import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../Point/point_second.dart';
import '../Post/post_rental.dart';
import '../Chat/chatlist.dart';
import '../Home/home.dart';
import '../MyPage/mypage.dart';
import '../Search/search.dart';
import '../login.dart';

class LikeScreen extends StatefulWidget {
  @override
  _LikeScreenState createState() => _LikeScreenState();
}

class _LikeScreenState extends State<LikeScreen> {
  int _selectedIndex = 1;
  List<Map<String, dynamic>> likedItems = [];
  String? studentNum;

  @override
  void initState() {
    super.initState();
    checkPenaltyAndForceLogout(context);
    loadLikedItems();
  }

  Future<void> checkPenaltyAndForceLogout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final studentNum = prefs.getString('studentNum');
    if (studentNum == null) return;

    final response = await http.get(
      Uri.parse('http://54.79.35.255:8080/penalties/$studentNum'),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      final isBanned = data['banned'];
      final penaltyScore = data['penaltyScore'];

      if (isBanned == true || penaltyScore >= 3) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            title: Row(
              children: [
                Text("계정 정지 안내", style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(width: 8),
                Image.asset(
                  'assets/redCard.png', // ← 경로 확인 필수
                  width: 24,
                  height: 24,
                ),
              ],
            ),
            content: Text("페널티 누적으로 계정이 정지되었습니다.\n자동으로 로그아웃 됩니다."),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xff97C663),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                onPressed: () async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.clear();

                  Navigator.of(context).pop(); // 팝업 먼저 닫고

                  // pop 이후 반드시 context mounted 체크
                  if (context.mounted) {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (context) => LoginScreen()),
                      (route) => false,
                    );
                  }
                },
                child: Text('확인'),
              ),
            ],
          ),
        );
      }
    }
  }

  String formatTimeDifference(DateTime createdAt) {
    final now = DateTime.now();
    final diff = now.difference(createdAt);

    if (diff.inMinutes < 1) return '방금 전';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    if (diff.inDays < 30) return '${diff.inDays}일 전';

    final months = diff.inDays ~/ 30;
    if (months < 12) return '${months}달 전';

    return '${createdAt.year}.${createdAt.month.toString().padLeft(2, '0')}.${createdAt.day.toString().padLeft(2, '0')}';
  }

  String formatDateTime(String dateTimeStr) {
    final dt = DateTime.parse(dateTimeStr);
    return '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Future<void> loadLikedItems() async {
    final prefs = await SharedPreferences.getInstance();
    studentNum = prefs.getString('studentNum');
    if (studentNum == null) return;

    final res = await http
        .get(Uri.parse('http://54.79.35.255:8080/likes/student/$studentNum'));

    if (res.statusCode == 200) {
      final List<dynamic> data = jsonDecode(utf8.decode(res.bodyBytes));

      List<Map<String, dynamic>> tempList = [];

      for (var e in data) {
        final rentalItemId = e['rentalItemId'];
        String imageUrl = 'assets/box.png';

        final imageRes = await http.get(Uri.parse(
            'http://54.79.35.255:8080/images/api/item/$rentalItemId'));
        if (imageRes.statusCode == 200) {
          final images = jsonDecode(utf8.decode(imageRes.bodyBytes));
          if (images.isNotEmpty) {
            final rawUrl = images[0]['imageUrl']?.toString();
            if (rawUrl != null && rawUrl.startsWith('/images/')) {
              imageUrl = 'http://54.79.35.255:8080$rawUrl';
            }
          }
        }

        tempList.add({
          'id': rentalItemId,
          'title': e['rentalItemTitle'],
          'rentalStartTime': e['rentalStartTime'],
          'rentalEndTime': e['rentalEndTime'],
          'imageUrl': imageUrl,
        });
      }

      setState(() {
        likedItems = tempList
          ..sort((a, b) {
            final aTime =
                DateTime.tryParse(a['rentalStartTime'] ?? '') ?? DateTime(2000);
            final bTime =
                DateTime.tryParse(b['rentalStartTime'] ?? '') ?? DateTime(2000);
            return bTime.compareTo(aTime); // 최신순 정렬
          });
      });
    } else {
      print('❌ 찜 목록 불러오기 실패');
    }
  }

  Future<void> toggleLike(int rentalItemId) async {
    if (studentNum == null) return;

    final url = Uri.parse(
        'http://54.79.35.255:8080/likes?studentNum=$studentNum&rentalItemId=$rentalItemId');
    final res = await http.post(url);

    if (res.statusCode == 200) {
      setState(() {
        likedItems.removeWhere((item) => item['id'] == rentalItemId);
      });
    } else {
      print('❌ 좋아요 취소 실패');
    }
  }

  void _onItemTapped(int index) {
    switch (index) {
      case 0:
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (context) => HomeScreen()));
        break;
      case 1:
        break;
      case 2:
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (context) => PointedScreen()));
        break;
      case 3:
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (context) => ChatListScreen()));
        break;
      case 4:
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (context) => MypageScreen()));
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xffF4F1F1),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              color: Color(0xffF4F1F1),
              child: Column(
                children: [
                  SizedBox(height: 15),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Padding(
                        padding: EdgeInsets.only(left: 30),
                        child: Text(
                          '관심 목록',
                          style: TextStyle(
                            fontSize: 24,
                            fontFamily: 'NanumSquare',
                            color: Color(0xff747A82),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.search),
                        color: Color(0xff97C663),
                        iconSize: 30,
                        padding: EdgeInsets.only(right: 10),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => SearchScreen()),
                          );
                        },
                      ),
                    ],
                  ),
                  SizedBox(height: 10),
                  Container(height: 1, color: Colors.grey[300]),
                ],
              ),
            ),
            Expanded(
              child: likedItems.isEmpty
                  ? Center(
                      child: Text('찜한 항목이 없습니다.',
                          style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      itemCount: likedItems.length,
                      itemBuilder: (context, index) {
                        final item = likedItems[index];
                        // final timeAgo = formatTimeDifference(createdAt);
                        return GestureDetector(
                          child: Column(
                            children: [
                              InkWell(
                                onTap: () async {
                                  final result = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          PostRentalScreen(itemId: item['id']),
                                    ),
                                  );

                                  if (result == true) {
                                    // 찜 상태 변경됨 → 목록 새로고침
                                    loadLikedItems();
                                  }
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 15.0, horizontal: 10.0),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      // 이미지
                                      Container(
                                        width: 90,
                                        height: 90,
                                        decoration: BoxDecoration(
                                          color: Color(0xffEBEBEB),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          child: Image.network(
                                            item['imageUrl'],
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error,
                                                    stackTrace) =>
                                                Image.asset('assets/box.png'),
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: 16),
                                      // 제목/설명/하트
                                      Expanded(
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment
                                              .start, // 텍스트 위로 정렬
                                          children: [
                                            // 왼쪽 (제목 + 설명)
                                            Expanded(
                                              flex: 3,
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    item['title'],
                                                    style: TextStyle(
                                                        fontFamily: 'Pretender',
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        fontSize: 16),
                                                  ),
                                                  SizedBox(height: 4),
                                                  Text(
                                                    (item['rentalStartTime'] ??
                                                                item[
                                                                    'startTime']) ==
                                                            null
                                                        ? '양도(무료나눔)'
                                                        : '${formatDateTime(item['rentalStartTime'] ?? item['startTime'])} ~ ${formatDateTime(item['rentalEndTime'] ?? item['endTime'])}',
                                                    style: TextStyle(
                                                      color: Colors.grey[700],
                                                      fontSize: 13,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            // 오른쪽 (좋아요 + 3시간 전)
                                            Expanded(
                                              flex: 1,
                                              child: Container(
                                                height: 90,
                                                child: Column(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.end,
                                                  children: [
                                                    GestureDetector(
                                                      onTap: () {
                                                        toggleLike(item['id']);
                                                      },
                                                      child: Icon(
                                                          Icons.favorite,
                                                          size: 30,
                                                          color: Colors.red),
                                                    ),
                                                    // Text(timeAgo,
                                                    //     style: TextStyle(
                                                    //         color: Colors.grey,
                                                    //         fontSize: 13)),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Divider(height: 1, color: Colors.grey[300]),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        color: Color(0xffEBEBEB),
        padding: const EdgeInsets.only(bottom: 5),
        child: BottomNavigationBar(
          backgroundColor: Color(0xffEBEBEB),
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          showSelectedLabels: true,
          showUnselectedLabels: true,
          selectedItemColor: Color(0xff97C663),
          unselectedItemColor: Colors.grey,
          selectedFontSize: 12,
          unselectedFontSize: 12,
          items: const [
            BottomNavigationBarItem(
                icon: Icon(Icons.home, size: 27), label: '홈'),
            BottomNavigationBarItem(
                icon: Icon(Icons.favorite, size: 27), label: '찜'),
            BottomNavigationBarItem(
                icon: Icon(Icons.control_point_duplicate_rounded, size: 27),
                label: '포인트'),
            BottomNavigationBarItem(
                icon: Icon(Icons.messenger_outline_rounded, size: 27),
                label: '채팅'),
            BottomNavigationBarItem(
                icon: Icon(Icons.person, size: 27), label: '마이페이지'),
          ],
        ),
      ),
    );
  }
}
