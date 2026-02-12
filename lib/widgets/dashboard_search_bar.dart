import 'package:flutter/material.dart';

class DashboardSearchBar extends StatelessWidget {
  final ValueChanged<String>? onChanged;
  final VoidCallback? onFilterPressed;
  final TextEditingController? controller;
  final VoidCallback? onTap;

  const DashboardSearchBar({
    Key? key,
    this.onChanged,
    this.onFilterPressed,
    this.controller,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Search Bar
        Expanded(
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F3F4),
              shape: BoxShape.rectangle,
              borderRadius: BorderRadius.circular(24), // Fully rounded ends
            ),
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              onTap: onTap,
              readOnly: true,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.black87,
                fontFamily: 'Roboto', // Default Flutter font is Roboto
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: 'Search',
                hintStyle: const TextStyle(
                  color: Color(0xFF5F6368), // Slightly darker grey for text
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                ),
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(
                    left: 16,
                    right: 8,
                    top: 0,
                    bottom: 0,
                  ),
                  child: Icon(
                    Icons.search,
                    color: Color(0xFF5F6368), // Darker grey for icon
                    size: 22,
                    weight: 700, // Bolder icon
                  ),
                ),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 40,
                  minHeight: 24,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                isDense: true,
              ),
            ),
          ),
        ),

        // Divider
        Container(
          height: 24,
          width: 1,
          margin: const EdgeInsets.symmetric(horizontal: 8),
          color: const Color(0xFFDADCE0), // Light grey divider
        ),

        // Filter Button
        Container(
          width: 48,
          height: 48,
          decoration: const BoxDecoration(
            color: Color(0xFFF1F3F4), // Match search bar color
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(
              Icons.tune,
              color: Color(0xFF5F6368), // Darker grey for icon
              size: 22,
              weight: 700, // Bolder icon
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: onFilterPressed,
          ),
        ),
      ],
    );
  }
}
