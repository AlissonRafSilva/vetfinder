enum AppUserRole {
  veterinarian(
    apiValue: 'VETERINARIAN',
    label: 'Veterinario volante',
  ),
  intern(
    apiValue: 'INTERN',
    label: 'Estagiario',
  ),
  clinic(
    apiValue: 'CLINIC',
    label: 'Clinica veterinaria',
  ),
  hospital(
    apiValue: 'HOSPITAL',
    label: 'Hospital veterinario',
  );

  const AppUserRole({
    required this.apiValue,
    required this.label,
  });

  final String apiValue;
  final String label;
}
