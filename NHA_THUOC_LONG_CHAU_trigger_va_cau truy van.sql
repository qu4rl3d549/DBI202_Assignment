﻿use [FPTLONGCHAU]
SELECT*FROM [dbo].[KHACHHANG]
SELECT*FROM [dbo].[CHINHANH]
SELECT*FROM [dbo].[NHANVIEN]
SELECT*FROM [dbo].[NHASANXUAT]
SELECT*FROM [dbo].[SANPHAM]
SELECT*FROM [dbo].[CAPBACTHANHVIEN]
SELECT*FROM [dbo].[TAIKHOAN]
SELECT*FROM [dbo].[DANHGIA]
SELECT*FROM [dbo].[KHOCHINHANH]
SELECT*FROM [dbo].[LUUTRU]
SELECT*FROM [dbo].[HOADON]
SELECT*FROM [dbo].[CHITIETHOADON]
GO
--Trigger: dùng trigger nếu người dùng muốn mua thêm hàng ví dụ số lượng 5--7 sản phẩm
CREATE TRIGGER TRG_UPDATE_SOLUONG
ON CHITIETHOADON
AFTER UPDATE
AS
BEGIN

    -- Cập nhật hàng tồn kho trong bảng 'LƯU TRỮ'
    UPDATE LUUTRU
    SET SOLUONGHANGTON = LT.SOLUONGHANGTON - (INS.SOLUONGSP - DEL.SOLUONGSP)
    FROM LUUTRU LT
    JOIN INSERTED INS ON LT.MASP = INS.MASP
    JOIN DELETED DEL ON INS.MASP = DEL.MASP AND INS.MAHD = DEL.MAHD;

    -- Cập nhật tổng tiền trong bảng 'CHI TIẾT HÓA ĐƠN'
    UPDATE CTHD
    SET CTHD.THANHTIEN = INS.SOLUONGSP * SP.GIA
    FROM CHITIETHOADON CTHD
    JOIN INSERTED INS ON CTHD.MASP = INS.MASP AND CTHD.MAHD = INS.MAHD
    JOIN SANPHAM SP ON CTHD.MASP = SP.MASP;

    -- Cập nhật tổng tiền trong bảng 'HÓA ĐƠN'
    UPDATE HD
    SET HD.TONGTIENTRUOCGIAMGIA = (
        SELECT SUM(CTHD.THANHTIEN)
        FROM CHITIETHOADON CTHD, HOADON HD
        WHERE CTHD.MAHD = HD.MAHD
		GROUP BY CTHD.MASP
    ),
        HD.SOTIENGIAMGIA = HD.TONGTIENTRUOCGIAMGIA* (CBTV.MUCGIAMGIA / 100),
        HD.TONGTIENSAUGIAMGIA = HD.TONGTIENTRUOCGIAMGIA - HD.SOTIENGIAMGIA
    FROM HOADON HD 
    JOIN INSERTED I ON HD.MAHD = I.MAHD
	JOIN KHACHHANG KH ON KH.MAKH=HD.MAKH
	JOIN TAIKHOAN TK ON TK.MAKH=KH.MAKH
	JOIN CAPBACTHANHVIEN CBTV ON CBTV.MATV=TK.MATV
	    -- Cập nhật doanh thu của chi nhánh
    UPDATE CN
    SET CN.DOANHTHU = (
        SELECT SUM(HD.TONGTIENSAUGIAMGIA)
        FROM HOADON HD
        WHERE HD.MACN = CN.MACN
    )
    FROM CHINHANH CN
    JOIN HOADON HD ON CN.MACN = HD.MACN
    JOIN INSERTED INS ON HD.MAHD = INS.MAHD;
END;
GO
--
UPDATE CHITIETHOADON
SET SOLUONGSP = 8 -- Tăng từ 5 → 7 → Giảm tồn kho, tăng doanh thu
WHERE MAHD = 'HD001' AND MASP = 'SP005'
GO

--truy vấn: In ra sản phẩm bán chạy nhất của nhà thuốc
DECLARE @TENSP NVARCHAR(200)
SELECT @TENSP=B.TENSP
FROM 
	(SELECT SP.MASP, SP.TENSP, SUM(CTHD.SOLUONGSP) AS TONG_SO_LUONG_BAN
	FROM SANPHAM SP JOIN CHITIETHOADON CTHD ON SP.MASP = CTHD.MASP
	GROUP BY SP.MASP, SP.TENSP
	HAVING SUM(CTHD.SOLUONGSP) = (
		SELECT MAX(TONG_SO_LUONG_BAN)
		FROM (
			SELECT SUM(CTHD.SOLUONGSP) AS TONG_SO_LUONG_BAN
			FROM CHITIETHOADON CTHD
			GROUP BY CTHD.MASP) AS A
	))B
PRINT N'SP BÁN CHẠY NHẤT LÀ: '+ @TENSP
GO
--truy vấn: cho biết thông tin số tiền mua,số lượng sản phẩm,tên sản phẩm, phân loại, đơn vị tính, tên khách hàng chi nhiều tiền nhất
SELECT B.TENKH, SP.TENSP,CTHD.SOLUONGSP, SP.PHANLOAI, SP.DONVITINH, B.TONG_TIEN
FROM
	(SELECT KH.TENKH,KH.MAKH, SUM(CTHD.THANHTIEN) AS TONG_TIEN
	FROM KHACHHANG KH 
	JOIN HOADON HD ON HD.MAKH=KH.MAKH
	JOIN CHITIETHOADON CTHD ON CTHD.MAHD=HD.MAHD
	JOIN SANPHAM SP ON SP.MASP=CTHD.MASP
	GROUP BY KH.MAKH, KH.TENKH
	HAVING SUM(CTHD.THANHTIEN) >= ALL( 
			(SELECT SUM(CTHD.THANHTIEN)
			FROM CHITIETHOADON CTHD JOIN HOADON HD ON HD.MAHD=CTHD.MAHD
			GROUP BY HD.MAKH)))B, SANPHAM SP, HOADON HD, CHITIETHOADON CTHD
WHERE B.MAKH=HD.MAKH AND SP.MASP=CTHD.MASP AND CTHD.MAHD=HD.MAHD
GO
--truy vấn: Lấy danh sách sản phẩm có số lượng tồn kho < 100
SELECT SP.MASP, SP.TENSP, LT.SOLUONGHANGTON
FROM SANPHAM SP JOIN LUUTRU LT ON LT.MASP=SP.MASP
WHERE LT.SOLUONGHANGTON < 100
--Truy vấn:  Tìm Khách Hàng Đánh Giá Cao Nhất
SELECT KH.TENKH, DG.MASP, SP.TENSP, DG.DG
FROM DANHGIA DG
JOIN TAIKHOAN TK ON DG.MATK = TK.MATK
JOIN SANPHAM SP ON DG.MASP = SP.MASP
JOIN KHACHHANG KH ON KH.MAKH=TK.MAKH
WHERE DG.DG = (SELECT MAX(DG) FROM DANHGIA);