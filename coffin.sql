
CREATE TABLE IF NOT EXISTS `phils_coffin_inventory` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `citizenid` varchar(50) NOT NULL,
  `animalhash` varchar(50) NOT NULL,
  `animallabel` varchar(50) NOT NULL,
  `animallooted` tinyint(1) NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=6 DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

