#!/bin/bash

# Azahar Bug Solver - Script para solucionar bugs del milestone 2125
# Herramienta para desarrolladores que trabajan en fixes
# Autor: Generado para el proyecto Azahar
# Fecha: 2026-01-31

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Configuración
MILESTONE_NUMBER=26
MILESTONE_NAME="2125"
REPO="azahar-emu/azahar"
REPO_URL="https://github.com/${REPO}"
API_URL="https://api.github.com/repos/${REPO}"
CACHE_FILE="/tmp/azahar_milestone_${MILESTONE_NUMBER}_cache.json"

# Directorio del proyecto (se detecta automáticamente)
PROJECT_DIR=""

# Banner
show_banner() {
    echo -e "${CYAN}${BOLD}"
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║     Azahar Bug Solver - Milestone ${MILESTONE_NAME}                  ║"
    echo "║     Herramienta para solucionar bugs                     ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Verificar dependencias
check_dependencies() {
    local missing_deps=()
    
    for cmd in git jq curl; do
        if ! command -v $cmd &> /dev/null; then
            missing_deps+=($cmd)
        fi
    done
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        echo -e "${RED}Error: Faltan las siguientes dependencias:${NC}"
        for dep in "${missing_deps[@]}"; do
            echo -e "  - ${YELLOW}$dep${NC}"
        done
        echo ""
        echo -e "${CYAN}Instala las dependencias con:${NC}"
        echo "  sudo apt-get install git jq curl"
        exit 1
    fi
}

# Detectar directorio del proyecto
detect_project_dir() {
    if [ -n "$PROJECT_DIR" ]; then
        return 0
    fi
    
    # Buscar en el directorio actual
    if [ -d ".git" ] && git remote -v | grep -q "azahar"; then
        PROJECT_DIR=$(pwd)
        echo -e "${GREEN}✓ Proyecto detectado en: ${PROJECT_DIR}${NC}"
        return 0
    fi
    
    # Buscar en directorios comunes
    local common_dirs=(
        "$HOME/azahar"
        "$HOME/projects/azahar"
        "$HOME/dev/azahar"
        "$HOME/Descargas/azahar"
        "/tmp/azahar"
    )
    
    for dir in "${common_dirs[@]}"; do
        if [ -d "$dir/.git" ]; then
            cd "$dir"
            if git remote -v | grep -q "azahar"; then
                PROJECT_DIR="$dir"
                echo -e "${GREEN}✓ Proyecto detectado en: ${PROJECT_DIR}${NC}"
                return 0
            fi
        fi
    done
    
    echo -e "${YELLOW}⚠ No se detectó el repositorio de Azahar${NC}"
    echo -e "${CYAN}Opciones:${NC}"
    echo "  1. Navega al directorio del proyecto y ejecuta el script"
    echo "  2. Clona el repositorio: git clone ${REPO_URL}"
    echo "  3. Especifica el directorio: export AZAHAR_DIR=/ruta/al/proyecto"
    return 1
}

# Clonar repositorio si no existe
clone_repo() {
    local target_dir=${1:-$HOME/azahar}
    
    if [ -d "$target_dir" ]; then
        echo -e "${YELLOW}El directorio $target_dir ya existe${NC}"
        read -p "¿Deseas eliminarlo y clonar de nuevo? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            return 1
        fi
        rm -rf "$target_dir"
    fi
    
    echo -e "${CYAN}Clonando repositorio de Azahar...${NC}"
    git clone --recursive "${REPO_URL}.git" "$target_dir"
    
    if [ $? -eq 0 ]; then
        PROJECT_DIR="$target_dir"
        cd "$PROJECT_DIR"
        echo -e "${GREEN}✓ Repositorio clonado exitosamente${NC}"
        return 0
    else
        echo -e "${RED}Error al clonar el repositorio${NC}"
        return 1
    fi
}

# Obtener información de un issue
get_issue_info() {
    local issue_number=$1
    
    if [ ! -f "$CACHE_FILE" ]; then
        echo -e "${YELLOW}Obteniendo información del issue...${NC}"
        curl -s "${API_URL}/issues/${issue_number}" > "/tmp/issue_${issue_number}.json"
        cat "/tmp/issue_${issue_number}.json"
    else
        cat "$CACHE_FILE" | jq ".[] | select(.number == ${issue_number})"
    fi
}

# Crear branch para trabajar en un bug
create_bug_branch() {
    local issue_number=$1
    
    if ! detect_project_dir; then
        echo -e "${RED}No se puede crear branch sin el repositorio${NC}"
        return 1
    fi
    
    cd "$PROJECT_DIR"
    
    # Obtener información del issue
    local issue_info=$(get_issue_info "$issue_number")
    
    if [ -z "$issue_info" ] || [ "$issue_info" = "null" ]; then
        echo -e "${RED}Issue #${issue_number} no encontrado${NC}"
        return 1
    fi
    
    local title=$(echo "$issue_info" | jq -r '.title')
    local is_bug=$(echo "$issue_info" | jq -r '.labels[] | select(.name == "bug") | .name')
    
    echo -e "${BOLD}${BLUE}Creando branch para issue #${issue_number}${NC}"
    echo -e "${BOLD}Título:${NC} ${title}"
    echo ""
    
    # Generar nombre de branch
    local branch_type="fix"
    [ -z "$is_bug" ] && branch_type="feature"
    
    local branch_name="${branch_type}/issue-${issue_number}"
    
    # Actualizar main/master
    echo -e "${CYAN}Actualizando rama principal...${NC}"
    local main_branch=$(git remote show origin | grep "HEAD branch" | cut -d ":" -f 2 | xargs)
    git fetch origin
    git checkout "$main_branch"
    git pull origin "$main_branch"
    
    # Crear nueva branch
    echo -e "${CYAN}Creando branch: ${branch_name}${NC}"
    git checkout -b "$branch_name"
    
    echo -e "${GREEN}✓ Branch creada exitosamente${NC}"
    echo -e "${YELLOW}Ahora puedes trabajar en el fix para el issue #${issue_number}${NC}"
    echo ""
    echo -e "${BOLD}Próximos pasos:${NC}"
    echo "  1. Haz tus cambios en el código"
    echo "  2. Compila y prueba: ${CYAN}./azahar_bug_solver.sh build${NC}"
    echo "  3. Haz commit: ${CYAN}./azahar_bug_solver.sh commit ${issue_number}${NC}"
    echo "  4. Crea PR: ${CYAN}./azahar_bug_solver.sh pr ${issue_number}${NC}"
}

# Compilar el proyecto
build_project() {
    if ! detect_project_dir; then
        echo -e "${RED}No se puede compilar sin el repositorio${NC}"
        return 1
    fi
    
    cd "$PROJECT_DIR"
    
    echo -e "${BOLD}${BLUE}Compilando Azahar...${NC}"
    echo ""
    
    # Detectar sistema operativo y compilar apropiadamente
    if [ -f "CMakeLists.txt" ]; then
        echo -e "${CYAN}Configurando con CMake...${NC}"
        
        mkdir -p build
        cd build
        
        cmake .. -DCMAKE_BUILD_TYPE=Debug
        
        echo -e "${CYAN}Compilando...${NC}"
        make -j$(nproc)
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓ Compilación exitosa${NC}"
            echo -e "${YELLOW}Ejecutable en: ${PROJECT_DIR}/build/bin/${NC}"
            return 0
        else
            echo -e "${RED}✗ Error en la compilación${NC}"
            return 1
        fi
    else
        echo -e "${RED}No se encontró CMakeLists.txt${NC}"
        return 1
    fi
}

# Ejecutar tests
run_tests() {
    if ! detect_project_dir; then
        echo -e "${RED}No se pueden ejecutar tests sin el repositorio${NC}"
        return 1
    fi
    
    cd "$PROJECT_DIR"
    
    echo -e "${BOLD}${BLUE}Ejecutando tests...${NC}"
    echo ""
    
    if [ -d "build" ]; then
        cd build
        if [ -f "CTestTestfile.cmake" ]; then
            ctest --output-on-failure
        else
            echo -e "${YELLOW}No se encontraron tests configurados${NC}"
        fi
    else
        echo -e "${YELLOW}Primero debes compilar el proyecto${NC}"
        echo "Ejecuta: ./azahar_bug_solver.sh build"
    fi
}

# Generar mensaje de commit
generate_commit_message() {
    local issue_number=$1
    local issue_info=$(get_issue_info "$issue_number")
    
    if [ -z "$issue_info" ] || [ "$issue_info" = "null" ]; then
        echo -e "${RED}Issue #${issue_number} no encontrado${NC}"
        return 1
    fi
    
    local title=$(echo "$issue_info" | jq -r '.title')
    local is_bug=$(echo "$issue_info" | jq -r '.labels[] | select(.name == "bug") | .name')
    
    local prefix="feat"
    [ -n "$is_bug" ] && prefix="fix"
    
    local commit_msg="${prefix}: ${title}

Fixes #${issue_number}

Changes:
- TODO: Describe your changes here

Testing:
- TODO: Describe how you tested this fix
"
    
    echo "$commit_msg"
}

# Hacer commit con mensaje generado
commit_changes() {
    local issue_number=$1
    
    if ! detect_project_dir; then
        echo -e "${RED}No se puede hacer commit sin el repositorio${NC}"
        return 1
    fi
    
    cd "$PROJECT_DIR"
    
    # Verificar que hay cambios
    if [ -z "$(git status --porcelain)" ]; then
        echo -e "${YELLOW}No hay cambios para hacer commit${NC}"
        return 1
    fi
    
    echo -e "${BOLD}${BLUE}Preparando commit para issue #${issue_number}${NC}"
    echo ""
    
    # Mostrar cambios
    echo -e "${CYAN}Cambios detectados:${NC}"
    git status --short
    echo ""
    
    # Generar mensaje de commit
    local commit_msg=$(generate_commit_message "$issue_number")
    
    # Guardar en archivo temporal
    echo "$commit_msg" > /tmp/commit_msg_${issue_number}.txt
    
    echo -e "${YELLOW}Mensaje de commit generado:${NC}"
    echo "─────────────────────────────────────────"
    cat /tmp/commit_msg_${issue_number}.txt
    echo "─────────────────────────────────────────"
    echo ""
    
    read -p "¿Deseas editar el mensaje? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        ${EDITOR:-nano} /tmp/commit_msg_${issue_number}.txt
    fi
    
    # Agregar todos los cambios
    git add -A
    
    # Hacer commit
    git commit -F /tmp/commit_msg_${issue_number}.txt
    
    echo -e "${GREEN}✓ Commit realizado exitosamente${NC}"
    echo ""
    echo -e "${BOLD}Próximos pasos:${NC}"
    echo "  1. Push: ${CYAN}git push origin $(git branch --show-current)${NC}"
    echo "  2. Crear PR: ${CYAN}./azahar_bug_solver.sh pr ${issue_number}${NC}"
}

# Generar descripción de PR
generate_pr_description() {
    local issue_number=$1
    local issue_info=$(get_issue_info "$issue_number")
    
    if [ -z "$issue_info" ] || [ "$issue_info" = "null" ]; then
        echo -e "${RED}Issue #${issue_number} no encontrado${NC}"
        return 1
    fi
    
    local title=$(echo "$issue_info" | jq -r '.title')
    local body=$(echo "$issue_info" | jq -r '.body // "No description"')
    
    local pr_desc="## Description

This PR fixes #${issue_number}: ${title}

## Changes Made

- TODO: List your changes here
- 
- 

## Testing

- [ ] Tested on Linux
- [ ] Tested on Windows
- [ ] Tested on macOS
- [ ] Tested on Android

### Test Results

TODO: Describe your test results

## Screenshots (if applicable)

TODO: Add screenshots if relevant

## Checklist

- [ ] Code follows project style guidelines
- [ ] Self-review completed
- [ ] Comments added for complex code
- [ ] Documentation updated
- [ ] No new warnings generated
- [ ] Tests added/updated
- [ ] All tests passing

## Related Issues

Fixes #${issue_number}

---

### Original Issue Description

${body}
"
    
    echo "$pr_desc"
}

# Crear Pull Request
create_pr() {
    local issue_number=$1
    
    if ! detect_project_dir; then
        echo -e "${RED}No se puede crear PR sin el repositorio${NC}"
        return 1
    fi
    
    cd "$PROJECT_DIR"
    
    # Verificar que gh está instalado
    if ! command -v gh &> /dev/null; then
        echo -e "${YELLOW}GitHub CLI (gh) no está instalado${NC}"
        echo ""
        echo -e "${CYAN}Opciones:${NC}"
        echo "  1. Instalar gh: https://cli.github.com/"
        echo "  2. Crear PR manualmente en: ${REPO_URL}/compare"
        echo ""
        
        # Generar descripción y guardar
        local pr_desc=$(generate_pr_description "$issue_number")
        echo "$pr_desc" > "/tmp/pr_description_${issue_number}.md"
        
        echo -e "${GREEN}✓ Descripción de PR guardada en: /tmp/pr_description_${issue_number}.md${NC}"
        echo ""
        echo -e "${BOLD}Para crear el PR manualmente:${NC}"
        echo "  1. Push tu branch: git push origin $(git branch --show-current)"
        echo "  2. Ve a: ${REPO_URL}/compare"
        echo "  3. Copia el contenido de /tmp/pr_description_${issue_number}.md"
        
        return 1
    fi
    
    # Verificar autenticación
    if ! gh auth status &> /dev/null; then
        echo -e "${YELLOW}No estás autenticado en GitHub CLI${NC}"
        echo "Ejecuta: gh auth login"
        return 1
    fi
    
    local current_branch=$(git branch --show-current)
    
    # Push de la branch
    echo -e "${CYAN}Haciendo push de la branch...${NC}"
    git push -u origin "$current_branch"
    
    # Generar título y descripción
    local issue_info=$(get_issue_info "$issue_number")
    local title=$(echo "$issue_info" | jq -r '.title')
    local pr_title="Fix #${issue_number}: ${title}"
    
    local pr_desc=$(generate_pr_description "$issue_number")
    echo "$pr_desc" > "/tmp/pr_description_${issue_number}.md"
    
    # Crear PR
    echo -e "${CYAN}Creando Pull Request...${NC}"
    gh pr create \
        --title "$pr_title" \
        --body-file "/tmp/pr_description_${issue_number}.md" \
        --label "bug" \
        --milestone "$MILESTONE_NAME"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Pull Request creado exitosamente${NC}"
    else
        echo -e "${RED}Error al crear el Pull Request${NC}"
        return 1
    fi
}

# Workflow completo para solucionar un bug
solve_bug_workflow() {
    local issue_number=$1
    
    echo -e "${BOLD}${BLUE}Iniciando workflow para solucionar issue #${issue_number}${NC}"
    echo ""
    
    # Paso 1: Crear branch
    echo -e "${BOLD}Paso 1/5: Creando branch${NC}"
    create_bug_branch "$issue_number"
    echo ""
    
    read -p "Presiona Enter cuando hayas hecho tus cambios..."
    echo ""
    
    # Paso 2: Compilar
    echo -e "${BOLD}Paso 2/5: Compilando proyecto${NC}"
    if ! build_project; then
        echo -e "${RED}La compilación falló. Corrige los errores y vuelve a intentar.${NC}"
        return 1
    fi
    echo ""
    
    # Paso 3: Tests
    echo -e "${BOLD}Paso 3/5: Ejecutando tests${NC}"
    run_tests
    echo ""
    
    read -p "¿Los tests pasaron correctamente? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Corrige los tests y vuelve a intentar${NC}"
        return 1
    fi
    
    # Paso 4: Commit
    echo -e "${BOLD}Paso 4/5: Haciendo commit${NC}"
    commit_changes "$issue_number"
    echo ""
    
    # Paso 5: PR
    echo -e "${BOLD}Paso 5/5: Creando Pull Request${NC}"
    create_pr "$issue_number"
    
    echo ""
    echo -e "${GREEN}${BOLD}✓ Workflow completado!${NC}"
}

# Configurar entorno de desarrollo
setup_dev_environment() {
    echo -e "${BOLD}${BLUE}Configurando entorno de desarrollo${NC}"
    echo ""
    
    # Detectar sistema operativo
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo -e "${CYAN}Sistema detectado: ${NAME} ${VERSION}${NC}"
    fi
    
    echo -e "${YELLOW}Instalando dependencias de compilación...${NC}"
    
    # Dependencias comunes para Azahar
    local deps=(
        "build-essential"
        "cmake"
        "git"
        "pkg-config"
        "libsdl2-dev"
        "qtbase5-dev"
        "qtmultimedia5-dev"
        "libqt5opengl5-dev"
        "libssl-dev"
        "libavcodec-dev"
        "libavformat-dev"
        "libswscale-dev"
    )
    
    echo -e "${CYAN}Dependencias a instalar:${NC}"
    for dep in "${deps[@]}"; do
        echo "  - $dep"
    done
    echo ""
    
    read -p "¿Deseas instalar estas dependencias? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        sudo apt-get update
        sudo apt-get install -y "${deps[@]}"
        
        echo -e "${GREEN}✓ Dependencias instaladas${NC}"
    fi
    
    # Clonar repositorio si no existe
    if ! detect_project_dir; then
        echo ""
        read -p "¿Deseas clonar el repositorio de Azahar? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            clone_repo
        fi
    fi
    
    echo ""
    echo -e "${GREEN}✓ Entorno configurado${NC}"
}

# Mostrar ayuda
show_help() {
    cat << EOF
${BOLD}Uso:${NC} $0 [comando] [opciones]

${BOLD}Comandos disponibles:${NC}

  ${GREEN}setup${NC}                   Configura el entorno de desarrollo
  ${GREEN}clone [dir]${NC}             Clona el repositorio de Azahar
  ${GREEN}branch <issue>${NC}          Crea una branch para trabajar en un issue
  ${GREEN}build${NC}                   Compila el proyecto
  ${GREEN}test${NC}                    Ejecuta los tests
  ${GREEN}commit <issue>${NC}          Hace commit con mensaje generado
  ${GREEN}pr <issue>${NC}              Crea un Pull Request
  ${GREEN}solve <issue>${NC}           Workflow completo para solucionar un bug
  ${GREEN}help${NC}                    Muestra esta ayuda

${BOLD}Workflow completo:${NC}

  ${CYAN}./azahar_bug_solver.sh solve 1022${NC}
  
  Este comando ejecuta todo el proceso:
  1. Crea branch
  2. Espera a que hagas cambios
  3. Compila el proyecto
  4. Ejecuta tests
  5. Hace commit
  6. Crea Pull Request

${BOLD}Workflow manual:${NC}

  ${CYAN}# 1. Configurar entorno (solo primera vez)
  ./azahar_bug_solver.sh setup
  
  # 2. Crear branch para un bug
  ./azahar_bug_solver.sh branch 1022
  
  # 3. Hacer cambios en el código...
  
  # 4. Compilar y probar
  ./azahar_bug_solver.sh build
  ./azahar_bug_solver.sh test
  
  # 5. Hacer commit
  ./azahar_bug_solver.sh commit 1022
  
  # 6. Crear PR
  ./azahar_bug_solver.sh pr 1022${NC}

${BOLD}Variables de entorno:${NC}

  ${YELLOW}AZAHAR_DIR${NC}    Directorio del proyecto Azahar
  ${YELLOW}EDITOR${NC}        Editor para mensajes de commit (default: nano)

${BOLD}Ejemplos:${NC}

  $0 setup                    # Configurar entorno
  $0 branch 1655              # Crear branch para issue #1655
  $0 solve 1022               # Solucionar issue #1022 (workflow completo)
  $0 build                    # Compilar proyecto
  $0 commit 1241              # Commit con mensaje generado
  $0 pr 1241                  # Crear Pull Request

${BOLD}Repositorio:${NC} ${BLUE}${REPO_URL}${NC}

EOF
}

# Main
main() {
    show_banner
    check_dependencies
    
    # Usar AZAHAR_DIR si está definido
    [ -n "$AZAHAR_DIR" ] && PROJECT_DIR="$AZAHAR_DIR"
    
    local command=${1:-help}
    
    case $command in
        setup)
            setup_dev_environment
            ;;
        clone)
            clone_repo "${2:-$HOME/azahar}"
            ;;
        branch)
            if [ -z "$2" ]; then
                echo -e "${RED}Error: Especifica el número del issue${NC}"
                exit 1
            fi
            create_bug_branch "$2"
            ;;
        build)
            build_project
            ;;
        test)
            run_tests
            ;;
        commit)
            if [ -z "$2" ]; then
                echo -e "${RED}Error: Especifica el número del issue${NC}"
                exit 1
            fi
            commit_changes "$2"
            ;;
        pr)
            if [ -z "$2" ]; then
                echo -e "${RED}Error: Especifica el número del issue${NC}"
                exit 1
            fi
            create_pr "$2"
            ;;
        solve)
            if [ -z "$2" ]; then
                echo -e "${RED}Error: Especifica el número del issue${NC}"
                exit 1
            fi
            solve_bug_workflow "$2"
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            echo -e "${RED}Comando no reconocido: $command${NC}\n"
            show_help
            exit 1
            ;;
    esac
}

main "$@"
