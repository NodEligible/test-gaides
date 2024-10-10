#!/bin/bash

import yaml

def replace_port(docker_compose_file, old_port, new_port):
    # Читання файлу docker-compose.yml
    try:
        with open(docker_compose_file, 'r') as file:
            compose_content = yaml.safe_load(file)
    except Exception as e:
        print(f"Помилка читання файлу: {e}")
        return

    # Перевірка наявності служб у файлі
    if 'services' not in compose_content:
        print("Файл не містить секції 'services'.")
        return

    updated = False  # Флаг для перевірки, чи були зміни

    # Перевірка кожної служби
    for service_name, service in compose_content['services'].items():
        if 'ports' in service:
            # Перевірка кожного порту у списку портів
            for i, port_mapping in enumerate(service['ports']):
                # Якщо порт у форматі "старий_порт:старий_порт" або "старий_порт:інший_порт"
                if isinstance(port_mapping, str) and f"{old_port}:" in port_mapping:
                    service['ports'][i] = port_mapping.replace(str(old_port), str(new_port), 1)
                    print(f"Змінено порт у службі '{service_name}': {port_mapping} -> {service['ports'][i]}")
                    updated = True
                # Якщо порт у форматі словника (більш складний випадок)
                elif isinstance(port_mapping, dict) and port_mapping.get('published') == old_port:
                    service['ports'][i]['published'] = new_port
                    print(f"Змінено порт у словниковому форматі в службі '{service_name}'.")
                    updated = True

    # Якщо не було змін, повідомити користувача
    if not updated:
        print(f"Порт {old_port} не знайдено в файлі {docker_compose_file}.")
        return

    # Запис змін до файлу
    try:
        with open(docker_compose_file, 'w') as file:
            yaml.dump(compose_content, file, default_flow_style=False)
        print(f"Порт {old_port} було змінено на {new_port} у {docker_compose_file}")
    except Exception as e:
        print(f"Помилка запису файлу: {e}")

# Використання скрипта
docker_compose_file = 'docker-compose.yml'  # Вкажіть шлях до файлу
old_port = 9005  # Порт, який потрібно замінити
new_port = 9003  # Новий порт

replace_port(docker_compose_file, old_port, new_port)
