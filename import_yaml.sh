#!/bin/bash

import yaml

def replace_port(docker_compose_file, 9005, 9003):
    # Читання файлу docker-compose.yml
    with open(docker_compose_file, 'r') as file:
        compose_content = yaml.safe_load(file)

    # Перевірка кожної служби
    for service in compose_content.get('services', {}).values():
        if 'ports' in service:
            # Перевірка кожного порту у списку портів
            for i, port_mapping in enumerate(service['ports']):
                # Якщо порт у форматі "старий_порт:старий_порт"
                if isinstance(port_mapping, str) and port_mapping.startswith(f"{9005}:"):
                    # Заміна порту
                    service['ports'][i] = port_mapping.replace(str(9005), str(9003), 1)
                # Якщо порт у форматі словника (більш складний випадок)
                elif isinstance(port_mapping, dict) and port_mapping.get('published') == 9005:
                    service['ports'][i]['published'] = 9003

    # Запис змін до файлу
    with open(docker_compose_file, 'w') as file:
        yaml.dump(compose_content, file, default_flow_style=False)

    print(f"Порт {9005} було змінено на {9003} у {docker_compose_file}")

# Використання скрипта
docker_compose_file = 'docker-compose.yml'  # Вкажіть шлях до файлу
old_port = 9005  # Порт, який потрібно замінити
new_port = 9003  # Новий порт

replace_port(docker_compose_file, 9005, 9003)
