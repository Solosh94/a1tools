// App Localizations
//
// Multi-language support for the A1 Tools app.
// Currently supports English (default) and Spanish.

import 'package:flutter/material.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static const List<Locale> supportedLocales = [
    Locale('en', 'US'), // English
    Locale('es', 'ES'), // Spanish
  ];

  // Get the current language code
  String get languageCode => locale.languageCode;

  // Translations map
  static final Map<String, Map<String, String>> _localizedValues = {
    'en': _englishTranslations,
    'es': _spanishTranslations,
  };

  String translate(String key) {
    return _localizedValues[locale.languageCode]?[key] ??
        _localizedValues['en']?[key] ??
        key;
  }

  // Convenience getters for common strings
  String get appName => translate('app_name');
  String get login => translate('login');
  String get logout => translate('logout');
  String get username => translate('username');
  String get password => translate('password');
  String get email => translate('email');
  String get cancel => translate('cancel');
  String get save => translate('save');
  String get delete => translate('delete');
  String get edit => translate('edit');
  String get confirm => translate('confirm');
  String get yes => translate('yes');
  String get no => translate('no');
  String get ok => translate('ok');
  String get error => translate('error');
  String get success => translate('success');
  String get loading => translate('loading');
  String get retry => translate('retry');
  String get refresh => translate('refresh');
  String get search => translate('search');
  String get settings => translate('settings');
  String get home => translate('home');
  String get profile => translate('profile');

  // Navigation
  String get inspection => translate('inspection');
  String get training => translate('training');
  String get messages => translate('messages');
  String get management => translate('management');
  String get guidelines => translate('guidelines');
  String get workHours => translate('work_hours');
  String get suggestions => translate('suggestions');
  String get calendar => translate('calendar');
  String get inventory => translate('inventory');
  String get routeOptimization => translate('route_optimization');

  // Inspection related
  String get newInspection => translate('new_inspection');
  String get inspectionList => translate('inspection_list');
  String get customerName => translate('customer_name');
  String get customerPhone => translate('customer_phone');
  String get address => translate('address');
  String get chimneyType => translate('chimney_type');
  String get condition => translate('condition');
  String get jobType => translate('job_type');
  String get jobCategory => translate('job_category');
  String get startTime => translate('start_time');
  String get endTime => translate('end_time');
  String get photos => translate('photos');
  String get signature => translate('signature');
  String get submit => translate('submit');
  String get issues => translate('issues');
  String get recommendations => translate('recommendations');

  // Time clock
  String get clockIn => translate('clock_in');
  String get clockOut => translate('clock_out');
  String get clockedIn => translate('clocked_in');
  String get clockedOut => translate('clocked_out');
  String get mySchedule => translate('my_schedule');

  // Calendar
  String get today => translate('today');
  String get week => translate('week');
  String get month => translate('month');
  String get day => translate('day');
  String get event => translate('event');
  String get newEvent => translate('new_event');
  String get allDay => translate('all_day');

  // Inventory
  String get scanBarcode => translate('scan_barcode');
  String get inStock => translate('in_stock');
  String get lowStock => translate('low_stock');
  String get outOfStock => translate('out_of_stock');
  String get quantity => translate('quantity');
  String get recordUsage => translate('record_usage');
  String get receiveStock => translate('receive_stock');

  // Route optimization
  String get optimizeRoute => translate('optimize_route');
  String get addStop => translate('add_stop');
  String get navigate => translate('navigate');
  String get totalDistance => translate('total_distance');
  String get estimatedTime => translate('estimated_time');

  // Training
  String get courses => translate('courses');
  String get tests => translate('tests');
  String get startTest => translate('start_test');
  String get submitTest => translate('submit_test');
  String get passed => translate('passed');
  String get failed => translate('failed');
  String get score => translate('score');

  // Misc
  String get noDataAvailable => translate('no_data_available');
  String get pleaseWait => translate('please_wait');
  String get connectionError => translate('connection_error');
  String get sessionExpired => translate('session_expired');
  String get permissionDenied => translate('permission_denied');
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['en', 'es'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

// English translations
const Map<String, String> _englishTranslations = {
  // General
  'app_name': 'A1 Tools',
  'login': 'Login',
  'logout': 'Logout',
  'username': 'Username',
  'password': 'Password',
  'email': 'Email',
  'cancel': 'Cancel',
  'save': 'Save',
  'delete': 'Delete',
  'edit': 'Edit',
  'confirm': 'Confirm',
  'yes': 'Yes',
  'no': 'No',
  'ok': 'OK',
  'error': 'Error',
  'success': 'Success',
  'loading': 'Loading...',
  'retry': 'Retry',
  'refresh': 'Refresh',
  'search': 'Search',
  'settings': 'Settings',
  'home': 'Home',
  'profile': 'Profile',

  // Navigation
  'inspection': 'Inspection',
  'training': 'Training',
  'messages': 'Messages',
  'management': 'Management',
  'guidelines': 'Guidelines',
  'work_hours': 'Work Hours',
  'suggestions': 'Suggestions',
  'calendar': 'Calendar',
  'inventory': 'Inventory',
  'route_optimization': 'Route Optimization',

  // Inspection
  'new_inspection': 'New Inspection',
  'inspection_list': 'Inspection List',
  'customer_name': 'Customer Name',
  'customer_phone': 'Phone Number',
  'address': 'Address',
  'chimney_type': 'Chimney Type',
  'condition': 'Condition',
  'job_type': 'Job Type',
  'job_category': 'Job Category',
  'start_time': 'Start Time',
  'end_time': 'End Time',
  'photos': 'Photos',
  'signature': 'Signature',
  'submit': 'Submit',
  'issues': 'Issues',
  'recommendations': 'Recommendations',

  // Time clock
  'clock_in': 'Clock In',
  'clock_out': 'Clock Out',
  'clocked_in': 'Clocked In',
  'clocked_out': 'Clocked Out',
  'my_schedule': 'My Schedule',

  // Calendar
  'today': 'Today',
  'week': 'Week',
  'month': 'Month',
  'day': 'Day',
  'event': 'Event',
  'new_event': 'New Event',
  'all_day': 'All Day',

  // Inventory
  'scan_barcode': 'Scan Barcode',
  'in_stock': 'In Stock',
  'low_stock': 'Low Stock',
  'out_of_stock': 'Out of Stock',
  'quantity': 'Quantity',
  'record_usage': 'Record Usage',
  'receive_stock': 'Receive Stock',

  // Route optimization
  'optimize_route': 'Optimize Route',
  'add_stop': 'Add Stop',
  'navigate': 'Navigate',
  'total_distance': 'Total Distance',
  'estimated_time': 'Estimated Time',

  // Training
  'courses': 'Courses',
  'tests': 'Tests',
  'start_test': 'Start Test',
  'submit_test': 'Submit Test',
  'passed': 'Passed',
  'failed': 'Failed',
  'score': 'Score',

  // Misc
  'no_data_available': 'No data available',
  'please_wait': 'Please wait...',
  'connection_error': 'Connection error. Please try again.',
  'session_expired': 'Session expired. Please login again.',
  'permission_denied': 'Permission denied',
};

// Spanish translations
const Map<String, String> _spanishTranslations = {
  // General
  'app_name': 'A1 Tools',
  'login': 'Iniciar Sesión',
  'logout': 'Cerrar Sesión',
  'username': 'Usuario',
  'password': 'Contraseña',
  'email': 'Correo Electrónico',
  'cancel': 'Cancelar',
  'save': 'Guardar',
  'delete': 'Eliminar',
  'edit': 'Editar',
  'confirm': 'Confirmar',
  'yes': 'Sí',
  'no': 'No',
  'ok': 'Aceptar',
  'error': 'Error',
  'success': 'Éxito',
  'loading': 'Cargando...',
  'retry': 'Reintentar',
  'refresh': 'Actualizar',
  'search': 'Buscar',
  'settings': 'Configuración',
  'home': 'Inicio',
  'profile': 'Perfil',

  // Navigation
  'inspection': 'Inspección',
  'training': 'Capacitación',
  'messages': 'Mensajes',
  'management': 'Administración',
  'guidelines': 'Guías',
  'work_hours': 'Horas de Trabajo',
  'suggestions': 'Sugerencias',
  'calendar': 'Calendario',
  'inventory': 'Inventario',
  'route_optimization': 'Optimización de Ruta',

  // Inspection
  'new_inspection': 'Nueva Inspección',
  'inspection_list': 'Lista de Inspecciones',
  'customer_name': 'Nombre del Cliente',
  'customer_phone': 'Teléfono',
  'address': 'Dirección',
  'chimney_type': 'Tipo de Chimenea',
  'condition': 'Condición',
  'job_type': 'Tipo de Trabajo',
  'job_category': 'Categoría de Trabajo',
  'start_time': 'Hora de Inicio',
  'end_time': 'Hora de Fin',
  'photos': 'Fotos',
  'signature': 'Firma',
  'submit': 'Enviar',
  'issues': 'Problemas',
  'recommendations': 'Recomendaciones',

  // Time clock
  'clock_in': 'Registrar Entrada',
  'clock_out': 'Registrar Salida',
  'clocked_in': 'Entrada Registrada',
  'clocked_out': 'Salida Registrada',
  'my_schedule': 'Mi Horario',

  // Calendar
  'today': 'Hoy',
  'week': 'Semana',
  'month': 'Mes',
  'day': 'Día',
  'event': 'Evento',
  'new_event': 'Nuevo Evento',
  'all_day': 'Todo el Día',

  // Inventory
  'scan_barcode': 'Escanear Código',
  'in_stock': 'En Stock',
  'low_stock': 'Stock Bajo',
  'out_of_stock': 'Sin Stock',
  'quantity': 'Cantidad',
  'record_usage': 'Registrar Uso',
  'receive_stock': 'Recibir Stock',

  // Route optimization
  'optimize_route': 'Optimizar Ruta',
  'add_stop': 'Agregar Parada',
  'navigate': 'Navegar',
  'total_distance': 'Distancia Total',
  'estimated_time': 'Tiempo Estimado',

  // Training
  'courses': 'Cursos',
  'tests': 'Pruebas',
  'start_test': 'Iniciar Prueba',
  'submit_test': 'Enviar Prueba',
  'passed': 'Aprobado',
  'failed': 'Reprobado',
  'score': 'Puntuación',

  // Misc
  'no_data_available': 'No hay datos disponibles',
  'please_wait': 'Por favor espere...',
  'connection_error': 'Error de conexión. Intente de nuevo.',
  'session_expired': 'Sesión expirada. Inicie sesión de nuevo.',
  'permission_denied': 'Permiso denegado',
};
