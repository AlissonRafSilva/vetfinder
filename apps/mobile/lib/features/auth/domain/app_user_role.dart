enum AppUserRole {
  veterinarian(
    apiValue: 'VETERINARIAN',
    label: 'Veterinário volante',
  ),
  intern(
    apiValue: 'INTERN',
    label: 'Estagiário',
  ),
  clinic(
    apiValue: 'CLINIC',
    label: 'Clínica veterinária',
  ),
  hospital(
    apiValue: 'HOSPITAL',
    label: 'Hospital veterinário',
  );

  const AppUserRole({
    required this.apiValue,
    required this.label,
  });

  final String apiValue;
  final String label;
}
