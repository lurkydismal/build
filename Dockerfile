FROM archlinux:latest

RUN pacman-key --init && pacman-key --populate archlinux

RUN pacman -Syu --noconfirm

RUN pacman -S --noconfirm --needed \
    binutils fd make llvm \
    clang mold ccache \
    mimalloc snappy zstd microsoft-gsl libunwind

RUN rm -rf /var/cache/pacman/pkg/* /tmp/*

WORKDIR /build

COPY . .

RUN ./build.sh

ENTRYPOINT [ "./out/main.out" ]
