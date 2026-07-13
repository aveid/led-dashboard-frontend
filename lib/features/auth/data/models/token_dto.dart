/// DTO ответа входа: JWT access-токен (см. `TokenResponse` на бэке).
///
/// Без кодогена: `fromJson` написан вручную (решение из frontend/CONTEXT.md §1).
/// DTO живёт в data-слое и не выходит в UI — это «форма JSON», а не сущность.
class TokenDto {
  const TokenDto({required this.accessToken, required this.tokenType});

  final String accessToken;
  final String tokenType;

  factory TokenDto.fromJson(Map<String, dynamic> json) {
    return TokenDto(
      accessToken: json['access_token'] as String,
      tokenType: (json['token_type'] as String?) ?? 'bearer',
    );
  }
}
