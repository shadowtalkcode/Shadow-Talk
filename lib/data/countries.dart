/// A country entry for the phone-number picker.
class Country {
  final String name;
  final String iso2; // ISO 3166-1 alpha-2 (used to derive the flag emoji)
  final String dialCode;

  const Country({required this.name, required this.iso2, required this.dialCode});

  /// Flag emoji derived from the ISO code via regional indicator symbols.
  String get flag {
    if (iso2.length != 2) return '🏳️';
    final base = 0x1F1E6;
    final a = iso2.codeUnitAt(0) - 0x41 + base;
    final b = iso2.codeUnitAt(1) - 0x41 + base;
    return String.fromCharCode(a) + String.fromCharCode(b);
  }
}

/// A practical subset of countries with international dial codes, sorted by name.
const List<Country> kCountries = [
  Country(name: 'Afghanistan', iso2: 'AF', dialCode: '+93'),
  Country(name: 'Albania', iso2: 'AL', dialCode: '+355'),
  Country(name: 'Algeria', iso2: 'DZ', dialCode: '+213'),
  Country(name: 'Argentina', iso2: 'AR', dialCode: '+54'),
  Country(name: 'Australia', iso2: 'AU', dialCode: '+61'),
  Country(name: 'Austria', iso2: 'AT', dialCode: '+43'),
  Country(name: 'Bangladesh', iso2: 'BD', dialCode: '+880'),
  Country(name: 'Belgium', iso2: 'BE', dialCode: '+32'),
  Country(name: 'Brazil', iso2: 'BR', dialCode: '+55'),
  Country(name: 'Bulgaria', iso2: 'BG', dialCode: '+359'),
  Country(name: 'Canada', iso2: 'CA', dialCode: '+1'),
  Country(name: 'Chile', iso2: 'CL', dialCode: '+56'),
  Country(name: 'China', iso2: 'CN', dialCode: '+86'),
  Country(name: 'Colombia', iso2: 'CO', dialCode: '+57'),
  Country(name: 'Croatia', iso2: 'HR', dialCode: '+385'),
  Country(name: 'Czech Republic', iso2: 'CZ', dialCode: '+420'),
  Country(name: 'Denmark', iso2: 'DK', dialCode: '+45'),
  Country(name: 'Egypt', iso2: 'EG', dialCode: '+20'),
  Country(name: 'Finland', iso2: 'FI', dialCode: '+358'),
  Country(name: 'France', iso2: 'FR', dialCode: '+33'),
  Country(name: 'Germany', iso2: 'DE', dialCode: '+49'),
  Country(name: 'Greece', iso2: 'GR', dialCode: '+30'),
  Country(name: 'Hong Kong', iso2: 'HK', dialCode: '+852'),
  Country(name: 'Hungary', iso2: 'HU', dialCode: '+36'),
  Country(name: 'Iceland', iso2: 'IS', dialCode: '+354'),
  Country(name: 'India', iso2: 'IN', dialCode: '+91'),
  Country(name: 'Indonesia', iso2: 'ID', dialCode: '+62'),
  Country(name: 'Iran', iso2: 'IR', dialCode: '+98'),
  Country(name: 'Iraq', iso2: 'IQ', dialCode: '+964'),
  Country(name: 'Ireland', iso2: 'IE', dialCode: '+353'),
  Country(name: 'Israel', iso2: 'IL', dialCode: '+972'),
  Country(name: 'Italy', iso2: 'IT', dialCode: '+39'),
  Country(name: 'Japan', iso2: 'JP', dialCode: '+81'),
  Country(name: 'Jordan', iso2: 'JO', dialCode: '+962'),
  Country(name: 'Kenya', iso2: 'KE', dialCode: '+254'),
  Country(name: 'Kuwait', iso2: 'KW', dialCode: '+965'),
  Country(name: 'Malaysia', iso2: 'MY', dialCode: '+60'),
  Country(name: 'Mexico', iso2: 'MX', dialCode: '+52'),
  Country(name: 'Morocco', iso2: 'MA', dialCode: '+212'),
  Country(name: 'Nepal', iso2: 'NP', dialCode: '+977'),
  Country(name: 'Netherlands', iso2: 'NL', dialCode: '+31'),
  Country(name: 'New Zealand', iso2: 'NZ', dialCode: '+64'),
  Country(name: 'Nigeria', iso2: 'NG', dialCode: '+234'),
  Country(name: 'Norway', iso2: 'NO', dialCode: '+47'),
  Country(name: 'Pakistan', iso2: 'PK', dialCode: '+92'),
  Country(name: 'Philippines', iso2: 'PH', dialCode: '+63'),
  Country(name: 'Poland', iso2: 'PL', dialCode: '+48'),
  Country(name: 'Portugal', iso2: 'PT', dialCode: '+351'),
  Country(name: 'Qatar', iso2: 'QA', dialCode: '+974'),
  Country(name: 'Romania', iso2: 'RO', dialCode: '+40'),
  Country(name: 'Russia', iso2: 'RU', dialCode: '+7'),
  Country(name: 'Saudi Arabia', iso2: 'SA', dialCode: '+966'),
  Country(name: 'Singapore', iso2: 'SG', dialCode: '+65'),
  Country(name: 'South Africa', iso2: 'ZA', dialCode: '+27'),
  Country(name: 'South Korea', iso2: 'KR', dialCode: '+82'),
  Country(name: 'Spain', iso2: 'ES', dialCode: '+34'),
  Country(name: 'Sri Lanka', iso2: 'LK', dialCode: '+94'),
  Country(name: 'Sweden', iso2: 'SE', dialCode: '+46'),
  Country(name: 'Switzerland', iso2: 'CH', dialCode: '+41'),
  Country(name: 'Thailand', iso2: 'TH', dialCode: '+66'),
  Country(name: 'Turkey', iso2: 'TR', dialCode: '+90'),
  Country(name: 'Ukraine', iso2: 'UA', dialCode: '+380'),
  Country(name: 'United Arab Emirates', iso2: 'AE', dialCode: '+971'),
  Country(name: 'United Kingdom', iso2: 'GB', dialCode: '+44'),
  Country(name: 'United States', iso2: 'US', dialCode: '+1'),
  Country(name: 'Vietnam', iso2: 'VN', dialCode: '+84'),
];
